Set-StrictMode -Version Latest

function Invoke-FileActivity {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    $localWorkspace = Resolve-ActivityPath -Path $Config.paths.localWorkspace
    if (-not (Test-Path -LiteralPath $localWorkspace)) {
        New-Item -ItemType Directory -Path $localWorkspace -Force | Out-Null
        Write-ActivityLog -Module "file" -Action "create-workspace" -Status "success" -Message "Created local workspace." -Data @{ path = $localWorkspace }
    }

    $count = Get-Random -Minimum ([int]$Config.file.createCountMin) -Maximum ([int]$Config.file.createCountMax + 1)
    $createdFiles = @()

    foreach ($index in 1..$count) {
        $extension = Get-Random -InputObject $Config.file.extensions
        $fileName = "work-item-{0}-{1}{2}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), (Get-Random -Minimum 1000 -Maximum 9999), $extension
        $filePath = Join-Path $localWorkspace $fileName
        $content = New-ActivityFileContent -Extension $extension
        Set-Content -LiteralPath $filePath -Value $content -Encoding UTF8
        $createdFiles += $filePath
        Write-ActivityLog -Module "file" -Action "create-file" -Status "success" -Message "Created $fileName." -Data @{ path = $filePath }
    }

    if ($Config.file.readExistingFiles) {
        $existingFiles = @(Get-ChildItem -LiteralPath $localWorkspace -File -ErrorAction SilentlyContinue)
        $readCount = [Math]::Min(3, $existingFiles.Count)
        if ($readCount -gt 0) {
            $existingFiles |
                Get-Random -Count $readCount |
                ForEach-Object {
                Get-Content -LiteralPath $_.FullName -TotalCount 5 -ErrorAction SilentlyContinue | Out-Null
                Write-ActivityLog -Module "file" -Action "read-file" -Status "success" -Message "Read a local work file." -Data @{ path = $_.FullName }
            }
        }
    }

    if ($Config.file.copyToNetworkShare) {
        Copy-ActivityFilesToShare -Files $createdFiles -SharePath $Config.paths.networkShare
    }

    if ($Config.file.deleteTemporaryFiles) {
        foreach ($file in $createdFiles | Get-Random -Count ([Math]::Floor($createdFiles.Count / 2))) {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            Write-ActivityLog -Module "file" -Action "delete-file" -Status "success" -Message "Deleted temporary file." -Data @{ path = $file }
        }
    }
}

function New-ActivityFileContent {
    param(
        [Parameter(Mandatory)]
        [string]$Extension
    )

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Extension.ToLowerInvariant()) {
        ".csv" {
            return @(
                "timestamp,category,value"
                "$now,ticket,$(Get-Random -Minimum 1000 -Maximum 9999)"
                "$now,document,$(Get-Random -Minimum 1 -Maximum 20)"
            )
        }
        ".json" {
            return (@{
                timestamp = $now
                activity = "normal-user-work"
                itemId = Get-Random -Minimum 1000 -Maximum 9999
                tags = @("client", "ad-lab", "simulation")
            } | ConvertTo-Json -Depth 4)
        }
        default {
            return @(
                "Activity note"
                "Created: $now"
                "User: $env:USERDOMAIN\$env:USERNAME"
                "Summary: Routine client workstation document update."
            )
        }
    }
}

function Copy-ActivityFilesToShare {
    param(
        [string[]]$Files,
        [Parameter(Mandatory)]
        [string]$SharePath
    )

    $resolvedShare = Resolve-ActivityPath -Path $SharePath
    if (-not (Test-Path -LiteralPath $resolvedShare)) {
        Write-ActivityLog -Module "file" -Action "copy-to-share" -Status "warning" -Message "Network share is not reachable." -Data @{ share = $resolvedShare }
        return
    }

    foreach ($file in $Files) {
        try {
            Copy-Item -LiteralPath $file -Destination $resolvedShare -Force
            Write-ActivityLog -Module "file" -Action "copy-to-share" -Status "success" -Message "Copied file to network share." -Data @{
                source = $file
                destination = $resolvedShare
            }
        }
        catch {
            Write-ActivityLog -Module "file" -Action "copy-to-share" -Status "error" -Message $_.Exception.Message -Data @{
                source = $file
                destination = $resolvedShare
            }
        }
    }
}
