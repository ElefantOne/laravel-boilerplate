<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Laravel\Octane\Commands\StartRoadRunnerCommand as OctaneStartRoadRunnerCommand;

/**
 * RoadRunner switched from calendar versions (2023.x - 2025.x) to semver (3.x).
 * Octane still requires >= 2023.3.0, so a Velox-built 3.x binary is treated as
 * outdated and replaced by a downloaded stock binary on start.
 */
class StartRoadRunnerCommand extends OctaneStartRoadRunnerCommand
{
    /** @var string */
    protected $requiredRoadRunnerVersion = '3.0.0';
}
