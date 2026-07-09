Set-StrictMode -Version Latest

function Invoke-NetworkActivity {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    foreach ($name in $Config.network.dnsQueries) {
        try {
            $result = Resolve-DnsName -Name $name -ErrorAction Stop | Select-Object -First 3 Name, Type, IPAddress, NameHost
            Write-ActivityLog -Module "network" -Action "dns-query" -Status "success" -Message "Resolved $name." -Data @{
                name = $name
                result = $result
            }
        }
        catch {
            Write-ActivityLog -Module "network" -Action "dns-query" -Status "warning" -Message "Could not resolve $name." -Data @{
                name = $name
                error = $_.Exception.Message
            }
        }
    }

    foreach ($port in $Config.network.testPorts) {
        try {
            $test = Test-NetConnection -ComputerName $Config.identity.domainController -Port ([int]$port) -InformationLevel Quiet -WarningAction SilentlyContinue
            $status = if ($test) { "success" } else { "warning" }
            Write-ActivityLog -Module "network" -Action "test-domain-port" -Status $status -Message "Tested $($Config.identity.domainController):$port." -Data @{
                host = $Config.identity.domainController
                port = [int]$port
                reachable = [bool]$test
            }
        }
        catch {
            Write-ActivityLog -Module "network" -Action "test-domain-port" -Status "warning" -Message $_.Exception.Message -Data @{
                host = $Config.identity.domainController
                port = [int]$port
            }
        }
    }

    foreach ($url in $Config.network.webUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10
            Write-ActivityLog -Module "network" -Action "web-request" -Status "success" -Message "Requested $url." -Data @{
                url = $url
                statusCode = [int]$response.StatusCode
            }
        }
        catch {
            Write-ActivityLog -Module "network" -Action "web-request" -Status "warning" -Message "Web request failed for $url." -Data @{
                url = $url
                error = $_.Exception.Message
            }
        }
    }

    if ($Config.network.runDomainDiscoveryCommands) {
        Invoke-LoggedCommand -Module "network" -Action "whoami" -FilePath "whoami.exe" -Arguments @("/all")
        Invoke-LoggedCommand -Module "network" -Action "nltest-dc" -FilePath "nltest.exe" -Arguments @("/dsgetdc:$($Config.identity.domainName)")
        Invoke-LoggedCommand -Module "network" -Action "gpresult" -FilePath "gpresult.exe" -Arguments @("/r")
        Invoke-LoggedCommand -Module "network" -Action "net-view" -FilePath "net.exe" -Arguments @("view", "\\$($Config.identity.domainController)")
    }
}
