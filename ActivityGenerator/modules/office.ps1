Set-StrictMode -Version Latest

function Invoke-OfficeActivity {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    if (-not $Config.office.enabled) {
        Write-ActivityLog -Module "office" -Action "skip" -Status "info" -Message "Office activity is disabled."
        return
    }

    $workspace = Resolve-ActivityPath -Path $Config.paths.localWorkspace
    if (-not (Test-Path -LiteralPath $workspace)) {
        New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    }

    if ($Config.office.createWordDocument) {
        New-ActivityWordDocument -Workspace $workspace -PreferComAutomation ([bool]$Config.office.preferComAutomation)
    }

    if ($Config.office.createExcelWorkbook) {
        New-ActivityExcelWorkbook -Workspace $workspace -PreferComAutomation ([bool]$Config.office.preferComAutomation)
    }
}

function New-ActivityWordDocument {
    param(
        [Parameter(Mandatory)]
        [string]$Workspace,

        [bool]$PreferComAutomation = $true
    )

    $path = Join-Path $Workspace ("status-note-{0}.docx" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    if ($PreferComAutomation) {
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $document = $word.Documents.Add()
            $selection = $word.Selection
            $selection.TypeText("Daily status note")
            $selection.TypeParagraph()
            $selection.TypeText("Created by $env:USERDOMAIN\$env:USERNAME on $(Get-Date).")
            $document.SaveAs([ref]$path)
            $document.Close()
            $word.Quit()
            Write-ActivityLog -Module "office" -Action "create-word" -Status "success" -Message "Created Word document." -Data @{ path = $path; automation = "com" }
            return
        }
        catch {
            Write-ActivityLog -Module "office" -Action "create-word" -Status "warning" -Message "Word automation failed; creating text fallback." -Data @{ error = $_.Exception.Message }
        }
    }

    $fallback = [System.IO.Path]::ChangeExtension($path, ".txt")
    Set-Content -LiteralPath $fallback -Value @(
        "Daily status note"
        "Created by $env:USERDOMAIN\$env:USERNAME on $(Get-Date)."
    ) -Encoding UTF8
    Write-ActivityLog -Module "office" -Action "create-word-fallback" -Status "success" -Message "Created text fallback for Word activity." -Data @{ path = $fallback }
}

function New-ActivityExcelWorkbook {
    param(
        [Parameter(Mandatory)]
        [string]$Workspace,

        [bool]$PreferComAutomation = $true
    )

    $path = Join-Path $Workspace ("activity-summary-{0}.xlsx" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    if ($PreferComAutomation) {
        try {
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $workbook = $excel.Workbooks.Add()
            $sheet = $workbook.Worksheets.Item(1)
            $sheet.Cells.Item(1, 1) = "Timestamp"
            $sheet.Cells.Item(1, 2) = "Activity"
            $sheet.Cells.Item(2, 1) = (Get-Date).ToString("s")
            $sheet.Cells.Item(2, 2) = "Normal workstation update"
            $workbook.SaveAs($path)
            $workbook.Close()
            $excel.Quit()
            Write-ActivityLog -Module "office" -Action "create-excel" -Status "success" -Message "Created Excel workbook." -Data @{ path = $path; automation = "com" }
            return
        }
        catch {
            Write-ActivityLog -Module "office" -Action "create-excel" -Status "warning" -Message "Excel automation failed; creating CSV fallback." -Data @{ error = $_.Exception.Message }
        }
    }

    $fallback = [System.IO.Path]::ChangeExtension($path, ".csv")
    Set-Content -LiteralPath $fallback -Value @(
        "Timestamp,Activity"
        """$((Get-Date).ToString("s"))"",""Normal workstation update"""
    ) -Encoding UTF8
    Write-ActivityLog -Module "office" -Action "create-excel-fallback" -Status "success" -Message "Created CSV fallback for Excel activity." -Data @{ path = $fallback }
}
