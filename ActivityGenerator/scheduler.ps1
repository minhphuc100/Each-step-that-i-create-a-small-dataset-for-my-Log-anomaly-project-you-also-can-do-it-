Set-StrictMode -Version Latest

function Start-ActivitySchedule {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    $modules = @($Config.run.enabledModules)
    $iterations = [int]$Config.run.iterations

    for ($iteration = 1; $iteration -le $iterations; $iteration++) {
        $module = Get-Random -InputObject $modules
        Write-ActivityLog -Module "scheduler" -Action "iteration" -Status "info" -Message "Starting iteration $iteration of $iterations with module '$module'." -Data @{
            iteration = $iteration
            total = $iterations
            selectedModule = $module
        }

        switch ($module.ToLowerInvariant()) {
            "file" { Invoke-FileActivity -Config $Config }
            "office" { Invoke-OfficeActivity -Config $Config }
            "idle" { Invoke-IdleActivity -Config $Config }
            "network" { Invoke-NetworkActivity -Config $Config }
            default {
                Write-ActivityLog -Module "scheduler" -Action "unknown-module" -Status "warning" -Message "Unknown module '$module'."
            }
        }

        if ($iteration -lt $iterations) {
            $delay = Get-Random -Minimum ([int]$Config.run.minDelaySeconds) -Maximum ([int]$Config.run.maxDelaySeconds + 1)
            Write-ActivityLog -Module "scheduler" -Action "delay" -Status "info" -Message "Waiting $delay seconds before next activity." -Data @{ seconds = $delay }
            Start-Sleep -Seconds $delay
        }
    }

    Write-ActivityLog -Module "scheduler" -Action "complete" -Status "success" -Message "Activity schedule completed."
}
