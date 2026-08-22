<#
  src/functions/Utilities.ps1
  AICKARAWINUTIL - Utilities module

  Dot-sourced (local run) or downloaded + dot-sourced (remote "irm | iex"
  run) by the main script the first time menu option 7 is selected. Depends
  on helper functions already defined in the main script: Write-Status,
  Write-Log, Confirm-Action, Invoke-Safely, and on $script:DataRoot.

  Contains:
    - Power utilities (this file): Shutdown Timer, Shutdown-when-Steam-
      finishes, Cancel Scheduled Shutdown, Restart to BIOS/UEFI.
    - Network Access Control: lives in its own file, src/functions/AIC.ps1,
      and is lazy-loaded by Import-AICModule below the first time it's
      selected from the Utilities menu. It's a reversible, AICKARA-owned
      Windows Firewall + hosts-file manager for controlling which locally
      installed applications can reach the network. AIC.ps1's entry point
      is expected to be a function named Invoke-AccessControl.

  NOTE: A "Block Adobe Services" item was requested early on and
  intentionally left out. Hosts-file/firewall blocking of a vendor's
  license-validation servers is a common software-piracy technique, so it
  isn't built in here. The Network Access Control feature is a
  general-purpose tool for things like telemetry/update/bandwidth control
  on apps you choose - it makes no claims about, and is not intended for,
  bypassing licensing or DRM. Entries whose evident purpose is defeating a
  license/activation check shouldn't be added even though the general
  mechanism is available.
#>

# ============================================================================
# SECTION 1: Power utilities
# ============================================================================

function Get-SteamInstallPath {
    foreach ($regPath in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $prop = Get-ItemProperty -Path $regPath -ErrorAction Stop
            $path = $prop.SteamPath
            if (-not $path) { $path = $prop.InstallPath }
            if ($path -and (Test-Path $path)) { return $path.Replace('/', '\') }
        } catch { }
    }
    return $null
}

function Invoke-ShutdownTimer {
    Write-Host ''
    $minutesInput = Read-Host 'Shut down after how many minutes? (e.g. 30)'
    $minutes = 0
    if (-not [int]::TryParse($minutesInput, [ref]$minutes) -or $minutes -le 0) {
        Write-Status 'Enter a whole number of minutes greater than 0.' Warn
        return
    }
    $seconds = $minutes * 60
    $when = (Get-Date).AddMinutes($minutes)
    if (-not (Confirm-Action "schedule a shutdown in $minutes minute(s)" "Machine will shut down at approximately $($when.ToString('HH:mm:ss')). Use 'Cancel Scheduled Shutdown' to abort.")) { return }
    Invoke-Safely "Scheduling shutdown in $minutes minute(s)" {
        shutdown /s /t $seconds /c "AICKARAWINUTIL: scheduled shutdown in $minutes minute(s)."
    } | Out-Null
}

function Invoke-ShutdownWhenSteamFinishes {
    Write-Host ''
    $steamPath = Get-SteamInstallPath
    if (-not $steamPath) {
        $steamPath = Read-Host 'Steam install path was not auto-detected. Enter it manually (e.g. C:\Program Files (x86)\Steam)'
    }
    if (-not $steamPath -or -not (Test-Path $steamPath)) {
        Write-Status 'A valid Steam install path is required.' Bad
        return
    }
    $downloadingDir = Join-Path $steamPath 'steamapps\downloading'
    if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) {
        Write-Status 'Steam does not appear to be running.' Warn
        if ((Read-Host 'Continue watching for downloads anyway? (Y/N)') -notmatch '^[Yy]') { return }
    }
    if (-not (Confirm-Action 'watch for Steam downloads to finish, then shut down' "Watching: $downloadingDir`nThis polls every 30 seconds. Press Ctrl+C at any time to stop watching (that will NOT schedule a shutdown).")) { return }

    Write-Status 'Watching Steam downloads...' Info
    $stableChecks = 0
    try {
        while ($true) {
            if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) {
                Write-Status 'Steam is no longer running. Stopping the watch without scheduling a shutdown.' Warn
                return
            }
            $active = $false
            if (Test-Path $downloadingDir) {
                $active = @(Get-ChildItem -LiteralPath $downloadingDir -Force -ErrorAction SilentlyContinue).Count -gt 0
            }
            if ($active) {
                $stableChecks = 0
                Write-Status "Steam is still downloading... ($([DateTime]::Now.ToString('HH:mm:ss')))" Info
            } else {
                $stableChecks++
                Write-Status "No active downloads detected ($stableChecks/3 checks)." Info
            }
            if ($stableChecks -ge 3) { break }
            Start-Sleep -Seconds 30
        }
    } catch {
        Write-Status 'Watch interrupted; no shutdown was scheduled.' Warn
        return
    }

    Write-Status 'Steam downloads appear finished.' Good
    if (-not (Confirm-Action 'schedule a shutdown now that downloads look finished' "A 60-second shutdown will be scheduled so you can cancel it (Utilities > Cancel Scheduled Shutdown) if you're still around.")) { return }
    Invoke-Safely 'Scheduling shutdown after Steam downloads finished' {
        shutdown /s /t 60 /c 'AICKARAWINUTIL: Steam downloads finished, shutting down in 60 seconds.'
    } | Out-Null
}

function Invoke-CancelScheduledShutdown {
    Invoke-Safely 'Cancelling scheduled shutdown' { shutdown /a } | Out-Null
}

function Invoke-RestartToBIOS {
    Write-Host ''
    Write-Status 'This restarts the PC directly into UEFI firmware settings. Only works on UEFI systems - legacy BIOS systems will just do a normal restart.' Warn
    if (-not (Confirm-Action 'restart into UEFI/BIOS firmware settings' 'The PC will restart immediately once confirmed. Save any open work first.')) { return }
    Invoke-Safely 'Restarting to UEFI firmware settings' { shutdown /r /fw /t 0 } | Out-Null
}

# ============================================================================
# SECTION 2: Network Access Control (Firewall / Hosts) - lazy-loaded from AIC.ps1
# ============================================================================
# The actual implementation lives in src/functions/AIC.ps1, kept separate so
# it can be authored/versioned on its own. This just knows how to find and
# load it, mirroring how the main script loads Utilities.ps1 itself.

$script:AICPath        = if ($script:FunctionsRoot) { Join-Path $script:FunctionsRoot 'AIC.ps1' } else { $null }
$script:RemoteAICUrl    = 'https://raw.githubusercontent.com/Vengeance239/aickarawinutil/refs/heads/main/src/functions/AIC.ps1'
$script:AICLoaded       = $false

function Import-AICModule {
    if ($script:AICLoaded) { return }
    if ($script:IsRemoteRun) {
        try {
            $code = Invoke-RestMethod -Uri $script:RemoteAICUrl -UseBasicParsing
            . ([ScriptBlock]::Create($code))
        } catch { throw "Could not download the AIC (Network Access Control) module: $($_.Exception.Message)" }
    } else {
        if (-not (Test-Path $script:AICPath)) { throw "AIC module not found: $script:AICPath" }
        . $script:AICPath
    }
    $script:AICLoaded = $true
    Write-Log 'AIC (Network Access Control) module loaded.' INFO
}

# ============================================================================
# SECTION 3: Utilities menu (entry point)
# ============================================================================

function Invoke-Utilities {
    while ($true) {
        Clear-Host
        Write-Host 'UTILITIES' -ForegroundColor Cyan
        Write-Host '1. Shutdown Timer'
        Write-Host '2. Shutdown when Steam finishes'
        Write-Host '3. Cancel Scheduled Shutdown'
        Write-Host '4. Restart to BIOS / UEFI'
        Write-Host '5. Network Access Control (Firewall / Hosts)'
        Write-Host '0. Back'
        switch (Read-Host 'Choose 0-5') {
            '1' { Invoke-ShutdownTimer }
            '2' { Invoke-ShutdownWhenSteamFinishes }
            '3' { Invoke-CancelScheduledShutdown }
            '4' { Invoke-RestartToBIOS }
            '5' { Invoke-Safely 'Loading Network Access Control module' { Import-AICModule } | Out-Null; if ($script:AICLoaded) { Invoke-AccessControl } }
            '0' { return }
            default { Write-Status 'Invalid selection.' Warn }
        }
        Read-Host 'Press Enter to return to Utilities menu' | Out-Null
    }
}
