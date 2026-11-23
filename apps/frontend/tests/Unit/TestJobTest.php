<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Jobs\TestJob;
use PHPUnit\Framework\TestCase;

final class TestJobTest extends TestCase
{
    public function test_job_runs_the_requested_iteration(): void
    {
        $this->expectOutputString("Executing this job...\n");

        (new TestJob(1))->handle();
    }

    public function test_job_with_no_iterations_produces_no_output(): void
    {
        $this->expectOutputString('');

        (new TestJob(0))->handle();
    }
}
