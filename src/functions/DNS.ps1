# DNS and network helper functions loaded by main script when available
# Designed for PowerShell 5.1 compatibility (Windows 10/11)

function Get-ActiveNetworkAdapter {
    <#
    .SYNOPSIS
    Return the preferred/active IPv4 network adapter (InterfaceAlias) based on connected state and metric.
    .OUTPUTS string
    #>
    try {
        $interfaces = Get-NetIPInterface -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ConnectionState -eq 'Connected' } | Sort-Object -Property InterfaceMetric
        if (-not $interfaces) { return $null }
        return $interfaces[0].InterfaceAlias
    } catch {
        Write-Log "Get-ActiveNetworkAdapter failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Get-DnsSettings {
    <#
    .SYNOPSIS
    Show DNS server addresses for a given adapter or all adapters.
    .PARAMETER Adapter
    Optional InterfaceAlias. If omitted, shows all adapters.
    .OUTPUTS PSCustomObject
    #>
    param([string]$Adapter)
    try {
        $out = @()
        if ($Adapter) {
            $addrs = Get-DnsClientServerAddress -InterfaceAlias $Adapter -AddressFamily IPv4 -ErrorAction Stop
            $out += [PSCustomObject]@{ Adapter = $Adapter; ServerAddresses = $addrs.ServerAddresses -join ', ' }
        } else {
            $all = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop
            foreach ($a in $all) { $out += [PSCustomObject]@{ Adapter = $a.InterfaceAlias; ServerAddresses = $a.ServerAddresses -join ', ' } }
        }
        return $out
    } catch {
        Write-Log "Get-DnsSettings failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Save-DnsSnapshot {
    <#
    Save current DNS settings for the given adapter (or all) to a snapshot file for rollback.
    #>
    param([string]$Adapter)
    try {
        $snap = @()
        $targets = if ($Adapter) { @($Adapter) } else { (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop).InterfaceAlias }
        foreach ($a in $targets) {
            $addr = Get-DnsClientServerAddress -InterfaceAlias $a -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $snap += [PSCustomObject]@{ Interface = $a; ServerAddresses = $addr.ServerAddresses }
        }
        $path = Join-Path $script:DataRoot ('dns-snapshot_{0:yyyyMMdd_HHmmss}.json' -f (Get-Date))
        $snap | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
        Write-Log "DNS snapshot saved: $path" INFO
        return $path
    } catch {
        Write-Log "Save-DnsSnapshot failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Restore-DnsFromSnapshot {
    <#
    .SYNOPSIS
    Restore DNS server addresses from a snapshot file created with Save-DnsSnapshot.
    .PARAMETER Path
    Path to snapshot JSON file.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { Write-Status 'Snapshot not found.' Bad; return }
    $snap = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    foreach ($entry in $snap) {
        if (-not (Confirm-Action "Restore DNS for $($entry.Interface)" "Set servers: $($entry.ServerAddresses -join ', ')?")) { continue }
        try {
            Set-DnsClientServerAddress -InterfaceAlias $entry.Interface -ServerAddresses $entry.ServerAddresses -ErrorAction Stop
            Write-Log "Restored DNS for $($entry.Interface)" INFO
            Write-Status "Restored DNS for $($entry.Interface)" Good
        } catch {
            Write-Log "Restore-DnsFromSnapshot failed for $($entry.Interface): $($_.Exception.Message)" ERROR
            Write-Status "Failed to restore DNS for $($entry.Interface): $($_.Exception.Message)" Bad
        }
    }
}

function Set-DnsServers {
    <#
    .SYNOPSIS
    Set DNS servers for the active or specified adapter. Supports presets: Default (DHCP), Cloudflare, Google.
    .PARAMETER Adapter
    InterfaceAlias of adapter. If omitted active adapter is used.
    .PARAMETER Preset
    One of: DHCP, Cloudflare, Google, Custom. For Custom, pass -Servers.
    .PARAMETER Servers
    Array of IPv4 addresses.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$Adapter,
        [ValidateSet('DHCP','Cloudflare','Google','Custom')][string]$Preset = 'Cloudflare',
        [string[]]$Servers
    )

    if (-not $Adapter) { $Adapter = Get-ActiveNetworkAdapter }
    if (-not $Adapter) { Write-Status 'No active network adapter found.' Bad; return }

    switch ($Preset) {
        'DHCP'      { $serversToSet = @('') }
        'Cloudflare'{ $serversToSet = @('1.1.1.1','1.0.0.1') }
        'Google'    { $serversToSet = @('8.8.8.8','8.8.4.4') }
        'Custom'    { if (-not $Servers) { throw 'For Preset Custom you must specify -Servers' } else { $serversToSet = $Servers } }
    }

    $action = "Set DNS for $Adapter to $($serversToSet -join ', ')"
    if (-not $PSCmdlet.ShouldProcess($Adapter, $action)) { return }
    # Save snapshot for rollback
    $snapshot = Save-DnsSnapshot -Adapter $Adapter
    try {
        if ($Preset -eq 'DHCP') {
            Set-DnsClientServerAddress -InterfaceAlias $Adapter -ResetServerAddresses -ErrorAction Stop
        } else {
            Set-DnsClientServerAddress -InterfaceAlias $Adapter -ServerAddresses $serversToSet -ErrorAction Stop
        }
        Write-Log "Set DNS for $Adapter to $($serversToSet -join ', ')" INFO
        Write-Status "DNS updated for $Adapter" Good
        return $snapshot
    } catch {
        Write-Log "Set-DnsServers failed: $($_.Exception.Message)" ERROR
        Write-Status "Failed to set DNS: $($_.Exception.Message)" Bad
        return $null
    }
}
