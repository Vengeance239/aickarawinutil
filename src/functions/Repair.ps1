# Safe repair and maintenance helpers
function Invoke-SafeRepair {
    <#
    .SYNOPSIS
    Run SFC, DISM RestoreHealth, Winsock reset and DNS flush with staged prompts.
    #>
    [CmdletBinding()]
    param(
        [switch]$RunSFC,
        [switch]$RunDISM,
        [switch]$ResetWinsock,
        [switch]$FlushDNS
    )

    $steps = @()
    if ($RunSFC -or (-not ($RunSFC -or $RunDISM -or $ResetWinsock -or $FlushDNS))) { $steps += @{Name='SFC /scannow'; Action={ sfc /scannow }} }
    if ($RunDISM) { $steps += @{Name='DISM RestoreHealth'; Action={ DISM /Online /Cleanup-Image /RestoreHealth }} }
    if ($ResetWinsock) { $steps += @{Name='Winsock reset'; Action={ netsh winsock reset }} }
    if ($FlushDNS) { $steps += @{Name='Flush DNS'; Action={ ipconfig /flushdns }} }

    if (-not $steps) { Write-Status 'No repair steps selected.' Warn; return }
    if (-not (Confirm-Action "Run safe repair steps: $($steps.Name -join ', ')" 'These operations may take several minutes')) { return }

    foreach ($s in $steps) {
        Invoke-Safely $s.Name { & $s.Action } | Out-Null
    }
}
