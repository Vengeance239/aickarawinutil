# Network diagnostics and helper functions (Test & Report)
function Test-NetworkDiagnostics {
    <#
    .SYNOPSIS
    Run a set of network diagnostics for a target host and save a report to disk.
    .PARAMETER Host
    Hostname or IP to test (defaults to 8.8.8.8)
    .OUTPUTS string (path to report)
    #>
    param([string]$Host='8.8.8.8')
    $outDir = Join-Path $script:DataRoot 'Diagnostics'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $report = Join-Path $outDir ('network-report_{0:yyyyMMdd_HHmmss}.txt' -f (Get-Date))

    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("Network diagnostics report: $Host") | Out-Null
    $sb.AppendLine("Generated: $(Get-Date -Format 'u')") | Out-Null

    $sb.AppendLine('--- Ping (Test-Connection) ---')|Out-Null; try { $ping = Test-Connection -ComputerName $Host -Count 4 -ErrorAction Stop; $sb.AppendLine($ping | Out-String) | Out-Null } catch { $sb.AppendLine("Ping failed: $($_.Exception.Message)") | Out-Null }
    $sb.AppendLine('--- Traceroute (tracert.exe) ---')|Out-Null; try { $trace = tracert -d $Host; $sb.AppendLine($trace | Out-String) | Out-Null } catch { $sb.AppendLine('Traceroute failed') | Out-Null }
    $sb.AppendLine('--- DNS resolution ---')|Out-Null; try { $dns = Resolve-DnsName -Name $Host -ErrorAction Stop; $sb.AppendLine($dns | Out-String) | Out-Null } catch { $sb.AppendLine('DNS lookup failed or Resolve-DnsName unavailable') | Out-Null }
    $sb.AppendLine('--- Port checks (common ports) ---')|Out-Null
    foreach ($port in @(53,80,443,3389)) { $res = Test-NetConnection -ComputerName $Host -Port $port -WarningAction SilentlyContinue; $sb.AppendLine("Port $port: TcpTestSucceeded=$($res.TcpTestSucceeded) | RemoteAddress=$($res.RemoteAddress)") | Out-Null }

    $sb.ToString() | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Log "Network diagnostics saved to $report" INFO
    Write-Status "Network report saved: $report" Good
    return $report
}
