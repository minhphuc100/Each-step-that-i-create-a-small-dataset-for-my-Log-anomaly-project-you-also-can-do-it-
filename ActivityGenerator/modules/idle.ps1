Set-StrictMode -Version Latest

function Invoke-IdleActivity {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    $seconds = Get-Random -Minimum ([int]$Config.idle.minSeconds) -Maximum ([int]$Config.idle.maxSeconds + 1)
    Write-ActivityLog -Module "idle" -Action "wait" -Status "success" -Message "Simulating user idle time for $seconds seconds." -Data @{ seconds = $seconds }
    Start-Sleep -Seconds $seconds
}
