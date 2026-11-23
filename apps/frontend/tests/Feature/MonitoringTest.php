<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Exceptions\Handler;
use App\Models\User;
use App\Providers\AppServiceProvider;
use App\Providers\TelescopeServiceProvider;
use Illuminate\Support\Facades\Gate;
use Laravel\Telescope\IncomingEntry;
use Laravel\Telescope\Telescope;
use Psr\Log\LoggerInterface;
use RuntimeException;
use Sentry\State\HubInterface;
use Tests\TestCase;

final class MonitoringTest extends TestCase
{
    public function test_horizon_guest_access_follows_configuration(): void
    {
        config(['app.horizon.guest_view' => false]);
        $this->assertFalse(Gate::allows('viewHorizon'));

        config(['app.horizon.guest_view' => true]);
        $this->assertTrue(Gate::allows('viewHorizon'));
    }

    public function test_horizon_allows_only_configured_admins_when_guest_access_is_disabled(): void
    {
        config([
            'app.horizon.guest_view' => false,
            'app.horizon.admins.email_1' => 'first-admin@example.com',
            'app.horizon.admins.email_2' => 'second-admin@example.com',
        ]);

        $this->assertTrue(Gate::forUser(new User(['email' => 'first-admin@example.com']))->allows('viewHorizon'));
        $this->assertTrue(Gate::forUser(new User(['email' => 'second-admin@example.com']))->allows('viewHorizon'));
        $this->assertFalse(Gate::forUser(new User(['email' => 'other@example.com']))->allows('viewHorizon'));
    }

    public function test_local_application_registers_telescope_and_records_successful_requests(): void
    {
        $this->isolateTelescopeState();
        $this->app['env'] = 'local';
        config(['telescope.enabled' => false]);

        (new AppServiceProvider($this->app))->register();

        $this->assertTrue($this->app->providerIsLoaded(TelescopeServiceProvider::class));
        $this->assertTrue($this->app->providerIsLoaded(\Laravel\Telescope\TelescopeServiceProvider::class));
        $this->assertNotContains('_token', Telescope::$hiddenRequestParameters);

        $entry = IncomingEntry::make(['response_status' => 200]);
        Telescope::startRecording(false);
        Telescope::recordRequest($entry);

        $this->assertSame([$entry], Telescope::$entriesQueue);
    }

    public function test_non_local_telescope_filters_requests_and_hides_sensitive_input(): void
    {
        $this->isolateTelescopeState();
        $this->app->register(TelescopeServiceProvider::class);

        $this->assertContains('_token', Telescope::$hiddenRequestParameters);
        $this->assertContains('cookie', Telescope::$hiddenRequestHeaders);
        $this->assertContains('x-csrf-token', Telescope::$hiddenRequestHeaders);
        $this->assertContains('x-xsrf-token', Telescope::$hiddenRequestHeaders);

        $failure = IncomingEntry::make(['response_status' => 500]);
        Telescope::startRecording(false);
        Telescope::recordRequest(IncomingEntry::make(['response_status' => 200]));
        Telescope::recordRequest($failure);

        $this->assertSame([$failure], Telescope::$entriesQueue);
        $this->assertFalse(Gate::forUser(new User(['email' => 'user@example.com']))->allows('viewTelescope'));
    }

    public function test_exception_handler_reports_to_sentry_and_the_logger(): void
    {
        $exception = new RuntimeException('Example exception');
        $sentry = $this->createMock(HubInterface::class);
        $sentry->expects($this->once())->method('captureException')->with($exception);
        $this->app->instance('sentry', $sentry);

        $logger = $this->createMock(LoggerInterface::class);
        $logger->expects($this->once())->method('error')->with(
            'Example exception',
            $this->callback(static fn (array $context): bool => $context['exception'] === $exception),
        );
        $this->app->instance(LoggerInterface::class, $logger);

        (new Handler($this->app))->report($exception);
    }

    private function isolateTelescopeState(): void
    {
        $state = [
            Telescope::$authUsing,
            Telescope::$entriesQueue,
            Telescope::$filterUsing,
            Telescope::$hiddenRequestHeaders,
            Telescope::$hiddenRequestParameters,
            Telescope::$shouldRecord,
        ];
        Telescope::$entriesQueue = [];

        $this->beforeApplicationDestroyed(static function () use ($state): void {
            [
                Telescope::$authUsing,
                Telescope::$entriesQueue,
                Telescope::$filterUsing,
                Telescope::$hiddenRequestHeaders,
                Telescope::$hiddenRequestParameters,
                Telescope::$shouldRecord,
            ] = $state;
        });
    }
}
