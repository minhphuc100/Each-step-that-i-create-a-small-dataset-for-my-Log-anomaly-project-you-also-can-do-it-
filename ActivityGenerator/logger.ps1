Set-StrictMode -Version Latest
$script:ActivityLogFile = $null

function Initialize-ActivityLogger {
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    $resolved = Resolve-ActivityPath -Path $LogDirectory
    if (-not (Test-Path -LiteralPath $resolved)) {
        New-Item -ItemType Directory -Path $resolved -Force | Out-Null
    }

    $script:ActivityLogFile = Join-Path $resolved ("activity-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    Write-ActivityLog -Module "logger" -Action "start" -Status "success" -Message "Activity logger initialized."
    return $script:ActivityLogFile
}

function Resolve-ActivityPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    $expanded = $ExecutionContext.InvokeCommand.ExpandString($expanded)

    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }

    return (Join-Path (Get-Location) $expanded)
}

function Write-ActivityLog {
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Action,

        [ValidateSet("success", "warning", "error", "info")]
        [string]$Status = "info",

        [string]$Message = "",

        [hashtable]$Data = @{}
    )

    $entry = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        computer  = $env:COMPUTERNAME
        user      = "{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME
        module    = $Module
        action    = $Action
        status    = $Status
        message   = $Message
        data      = $Data
    }

    $line = $entry | ConvertTo-Json -Compress -Depth 8

    if ($script:ActivityLogFile) {
        Add-Content -LiteralPath $script:ActivityLogFile -Value $line
    }

    Write-Host ("[{0}] {1}/{2}: {3}" -f $Status.ToUpperInvariant(), $Module, $Action, $Message)
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    try {
        $output = & $FilePath @Arguments 2>&1 | Out-String
        $exitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
        $status = if ($exitCode -eq 0) { "success" } else { "warning" }
        Write-ActivityLog -Module $Module -Action $Action -Status $status -Message "$FilePath completed with exit code $exitCode." -Data @{
            filePath = $FilePath
            arguments = $Arguments
            exitCode = $exitCode
            output = $output.Trim()
        }
    }
    catch {
        Write-ActivityLog -Module $Module -Action $Action -Status "error" -Message $_.Exception.Message -Data @{
            filePath = $FilePath
            arguments = $Arguments
        }
    }
}
