param(
    [string]$ConfigPath = ".\config.json",
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

. "$projectRoot\logger.ps1"
. "$projectRoot\modules\file.ps1"
. "$projectRoot\modules\office.ps1"
. "$projectRoot\modules\idle.ps1"
. "$projectRoot\modules\network.ps1"
. "$projectRoot\scheduler.ps1"

function Read-ActivityConfig {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = Resolve-ActivityPath -Path $Path
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Config file was not found: $resolved"
    }

    return (Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json)
}

$config = Read-ActivityConfig -Path $ConfigPath
if ($Once) {
    $config.run.iterations = 1
}

$logFile = Initialize-ActivityLogger -LogDirectory $config.paths.logDirectory
Write-ActivityLog -Module "main" -Action "config-loaded" -Status "success" -Message "Loaded configuration." -Data @{
    configPath = (Resolve-ActivityPath -Path $ConfigPath)
    logFile = $logFile
}

Start-ActivitySchedule -Config $config
