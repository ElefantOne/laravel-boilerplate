<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Console\Commands\StartRoadRunnerCommand;
use App\Console\Kernel;
use Illuminate\Support\Facades\Storage;
use Laravel\Octane\Commands\StartRoadRunnerCommand as OctaneStartRoadRunnerCommand;
use Tests\TestCase;

final class ConsoleCommandsTest extends TestCase
{
    public function test_demo_command_formats_its_arguments(): void
    {
        $this->artisan('app:test-command', ['var1' => 'first value', 'var2' => 'second value'])
            ->expectsOutput('Result: first value - second value')
            ->assertSuccessful();
    }

    public function test_scheduled_command_prints_its_greeting(): void
    {
        $this->artisan('app:test-schedule-command')
            ->expectsOutput('Hello!')
            ->assertSuccessful();
    }

    public function test_demo_upload_creates_a_file_and_prints_its_url(): void
    {
        $disk = Storage::fake('s3', ['url' => 'https://storage.example.com/demo']);

        $this->artisan('app:test-put-file-command')
            ->expectsOutput('Result of upload is dumped.')
            ->expectsOutput('The file URL:')
            ->expectsOutput('https://storage.example.com/demo/first.txt')
            ->assertSuccessful();

        $this->assertSame('Some content', $disk->get('first.txt'));
    }

    public function test_demo_upload_keeps_an_existing_file(): void
    {
        $disk = Storage::fake('s3');
        $disk->put('first.txt', 'Original content');

        $this->artisan('app:test-put-file-command')
            ->expectsOutput('The file exists.')
            ->assertSuccessful();

        $this->assertSame('Original content', $disk->get('first.txt'));
    }

    public function test_application_kernel_configures_its_command_schedule(): void
    {
        config(['app.timezone' => 'Europe/Kyiv']);

        $kernel = $this->app->make(Kernel::class);
        $kernel->bootstrap();
        $events = $kernel->resolveConsoleSchedule()->events();

        $this->assertCount(2, $events);
        $this->assertStringContainsString('app:test-schedule-command', $events[0]->command);
        $this->assertSame('* * * * *', $events[0]->expression);
        $this->assertStringContainsString('horizon:snapshot', $events[1]->command);
        $this->assertSame('*/5 * * * *', $events[1]->expression);
        foreach ($events as $event) {
            $this->assertSame('Europe/Kyiv', $event->timezone);
        }
    }

    public function test_octane_resolves_the_application_roadrunner_command(): void
    {
        $this->assertInstanceOf(StartRoadRunnerCommand::class, $this->app->make(OctaneStartRoadRunnerCommand::class));
    }
}
