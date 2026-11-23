<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Helpers\TestHelper;
use Closure;
use Illuminate\Support\Facades\Log;
use Mockery;
use Symfony\Component\Process\Process;
use Tests\TestCase;
use ZMQ;
use ZMQContext;
use ZMQSocket;
use ZMQSocketException;

final class RpcTest extends TestCase
{
    public function test_go_command_sends_its_date_format_and_prints_the_reply(): void
    {
        $this->withResponder('MySocket-console-test1', 1, function (string $endpoint): void {
            config(['rpc.go_hello_addr' => $endpoint]);

            $this->artisan('app:test-go-rpc', ['n_iters' => 1])
                ->expectsOutput('Calling RPC #0...')
                ->expectsOutput('Reply: 2006-01-02 15:04:05')
                ->assertSuccessful();
        });
    }

    public function test_go_command_logs_a_connection_failure(): void
    {
        config(['rpc.go_hello_addr' => 'invalid-transport://demo']);
        Log::shouldReceive('error')->once()->with(
            Mockery::type('string'),
            Mockery::on(static fn (array $context): bool => $context['exception'] instanceof ZMQSocketException),
        );

        $this->artisan('app:test-go-rpc', ['n_iters' => 1])->assertSuccessful();
    }

    public function test_date_helper_returns_the_go_service_reply(): void
    {
        $this->withResponder('MySocket-test1', 1, function (string $endpoint): void {
            config(['rpc.go_hello_addr' => $endpoint]);

            $this->assertSame('Reply: 2006-01-02 15:04:05', TestHelper::currentDate());
        });
    }

    public function test_python_endpoint_sends_ten_numbered_requests_and_prints_the_replies(): void
    {
        $this->withResponder('MySocket-test', 10, function (string $endpoint): void {
            config(['rpc.python_hello_addr' => $endpoint]);

            ob_start();
            try {
                $response = $this->get('/start-test-python-zmq');
                $output = (string) ob_get_contents();
            } finally {
                ob_end_clean();
            }

            $response->assertOk()->assertContent('OK');
            for ($i = 1; $i <= 10; $i++) {
                $this->assertStringContainsString(
                    "Python RPC result: Reply: hello there, using MySocket-test: $i<br>",
                    $output,
                );
            }
        });
    }

    /** @param Closure(string): void $assertions */
    private function withResponder(string $socketId, int $requests, Closure $assertions): void
    {
        $responder = new Process([PHP_BINARY, __DIR__ . '/../Fixtures/zmq-responder.php', (string) $requests]);
        $responder->setTimeout(15);
        $responder->start();

        try {
            $ready = $responder->waitUntil(static fn (string $type, string $chunk): bool =>
                $type === Process::OUT && str_contains($chunk, "\n")
            );
            $this->assertTrue($ready, $responder->getErrorOutput());
            $endpoint = trim($responder->getOutput());
            $this->assertMatchesRegularExpression('/^tcp:\/\/127\.0\.0\.1:\d+$/', $endpoint);

            // The application opens this same persistent socket during the request.
            $socket = new ZMQSocket(new ZMQContext(), ZMQ::SOCKET_REQ, $socketId);
            $sendTimeout = $socket->getSockOpt(ZMQ::SOCKOPT_SNDTIMEO);
            $receiveTimeout = $socket->getSockOpt(ZMQ::SOCKOPT_RCVTIMEO);
            $socket->setSockOpt(ZMQ::SOCKOPT_SNDTIMEO, 5000);
            $socket->setSockOpt(ZMQ::SOCKOPT_RCVTIMEO, 5000);

            try {
                $assertions($endpoint);
                $this->assertSame(0, $responder->wait(), $responder->getErrorOutput());
            } finally {
                if (in_array($endpoint, $socket->getEndpoints()['connect'], true)) {
                    $socket->disconnect($endpoint);
                }
                $socket->setSockOpt(ZMQ::SOCKOPT_SNDTIMEO, $sendTimeout);
                $socket->setSockOpt(ZMQ::SOCKOPT_RCVTIMEO, $receiveTimeout);
            }
        } finally {
            $responder->stop(0);
        }
    }
}
