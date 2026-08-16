<#
    AICKARA UTIL LIGHT
    Fast, standalone Windows maintenance console.

    - No boot animations
    - No access code
    - No system/time/spec checks on startup
    - No restore point
    - No remote-access setup
    - No external PS1 modules
    - No external JSON configuration
    - App catalogue and bundles are embedded in this file
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '0.0.9-Lite'
$script:AppName = 'AICKARA WIN UTIL LITE'
$script:Cancelled = $false
$script:DataRoot = if ($env:ProgramData -and (Test-Path $env:ProgramData)) {
    Join-Path $env:ProgramData 'AICKARAWINUTIL'
} else {
    Join-Path $env:LOCALAPPDATA 'AICKARAWINUTIL'
}
$script:LogPath = Join-Path $script:DataRoot 'AICKARAWINUTIL.log'

# ---------------------------------------------------------------------------
# APP CATALOGUE
# ---------------------------------------------------------------------------

$script:AppCatalog = [ordered]@{
    'Chrome' = @{ Winget='Google.Chrome'; Choco='googlechrome'; Category='Productivity' }
    'WhatsApp Desktop' = @{ Winget='msstore:9NKSQGP7F2NH'; Choco='na'; Category='Communication' }
    'Adobe Acrobat Reader' = @{ Winget='Adobe.Acrobat.Reader.64-bit'; Choco='adobereader'; Category='Productivity' }
    'Visual C++ Redistributable x64' = @{ Winget='Microsoft.VCRedist.2015+.x64'; Choco='vcredist2015'; Category='Runtime / Dependencies' }
    'Visual C++ Redistributable x86' = @{ Winget='Microsoft.VCRedist.2015+.x86'; Choco='vcredist2015'; Category='Runtime / Dependencies' }
    '.NET Desktop Runtime 8' = @{ Winget='Microsoft.DotNet.DesktopRuntime.8'; Choco='dotnet-8.0-runtime'; Category='Runtime / Dependencies' }
    '7-Zip' = @{ Winget='7zip.7zip'; Choco='7zip'; Category='Utilities' }
    'VLC' = @{ Winget='VideoLAN.VLC'; Choco='vlc'; Category='Media' }

    'Revo Uninstaller' = @{ Winget='RevoUninstaller.RevoUninstaller'; Choco='revo-uninstaller'; Category='System Utilities' }
    'Everything' = @{ Winget='voidtools.Everything'; Choco='everything'; Category='System Utilities' }
    'Microsoft PC Manager' = @{ Winget='Microsoft.PCManager'; Choco='na'; Category='System Utilities' }
    'BleachBit' = @{ Winget='BleachBit.BleachBit'; Choco='bleachbit'; Category='Cleanup' }
    'DiskSavvy' = @{ Winget='Flexense.DiskSavvy'; Choco='disksavvy'; Category='Storage' }
    'Defraggler' = @{ Winget='Piriform.Defraggler'; Choco='defraggler'; Category='Storage' }

    'Microsoft Teams' = @{ Winget='Microsoft.Teams'; Choco='microsoft-teams'; Category='Communication' }
    'Zoom' = @{ Winget='Zoom.Zoom'; Choco='zoom'; Category='Communication' }

    'HWiNFO' = @{ Winget='REALiX.HWiNFO'; Choco='hwinfo'; Category='Hardware & Diagnostics' }
    'CPU-Z' = @{ Winget='CPUID.CPU-Z'; Choco='cpu-z'; Category='Hardware & Diagnostics' }
    'GPU-Z' = @{ Winget='TechPowerUp.GPU-Z'; Choco='gpu-z'; Category='Hardware & Diagnostics' }
    'CrystalDiskInfo' = @{ Winget='CrystalDewWorld.CrystalDiskInfo'; Choco='crystaldiskinfo'; Category='Hardware & Diagnostics' }
    'CrystalDiskMark' = @{ Winget='CrystalDewWorld.CrystalDiskMark'; Choco='crystaldiskmark'; Category='Benchmarks' }

    'Snappy Driver Installer Origin' = @{ Winget='GlennDelahoy.SnappyDriverInstallerOrigin'; Choco='sdio'; Category='Drivers' }
    'Autoruns' = @{ Winget='Microsoft.Sysinternals.Autoruns'; Choco='autoruns'; Category='Windows & Drivers' }
    'Process Explorer' = @{ Winget='Microsoft.Sysinternals.ProcessExplorer'; Choco='procexp'; Category='Windows & Drivers' }
    'DDU' = @{ Winget='Wagnardsoft.DisplayDriverUninstaller'; Choco='display-driver-uninstaller'; Category='Drivers' }
    'NVCleanstall' = @{ Winget='TechPowerUp.NVCleanstall'; Choco='na'; Category='Drivers' }

    'TCPView' = @{ Winget='Microsoft.Sysinternals.TCPView'; Choco='tcpview'; Category='Network' }
    'Advanced IP Scanner' = @{ Winget='Famatech.AdvancedIPScanner'; Choco='advanced-ip-scanner'; Category='Network' }
    'Nmap' = @{ Winget='Insecure.Nmap'; Choco='nmap'; Category='Network' }

    'HandBrake' = @{ Winget='HandBrake.HandBrake'; Choco='handbrake'; Category='Media' }
    'OBS Studio' = @{ Winget='OBSProject.OBSStudio'; Choco='obs-studio'; Category='Media & Streaming' }
    'ShareX' = @{ Winget='ShareX.ShareX'; Choco='sharex'; Category='Utilities' }
    'Spotify' = @{ Winget='Spotify.Spotify'; Choco='spotify'; Category='Media' }
    'JDownloader' = @{ Winget='JDownloader.JDownloader'; Choco='jdownloader'; Category='Downloads' }

    'Steam' = @{ Winget='Valve.Steam'; Choco='steam-client'; Category='Gaming' }
    'Discord' = @{ Winget='Discord.Discord'; Choco='discord'; Category='Gaming / Communication' }
    'MSI Afterburner' = @{ Winget='Guru3D.Afterburner'; Choco='msiafterburner'; Category='Gaming / Hardware' }

    'AnyDesk' = @{ Winget='AnyDesk.AnyDesk'; Choco='anydesk'; Category='Remote Support' }

    'System Informer' = @{ Winget='WinsiderSS.SystemInformer'; Choco='systeminformer'; Category='Advanced / Technician' }
    'Wireshark' = @{ Winget='WiresharkFoundation.Wireshark'; Choco='wireshark'; Category='Advanced / Technician' }
    'Rufus' = @{ Winget='Rufus.Rufus'; Choco='rufus'; Category='Boot / Recovery' }
}

$script:AppBundles = [ordered]@{
    'Level 1 : Office' = @(
        'Chrome','WhatsApp Desktop','Adobe Acrobat Reader',
        'Visual C++ Redistributable x64','Visual C++ Redistributable x86',
        '.NET Desktop Runtime 8','7-Zip','VLC'
    )
    'Level 2 : Laptop' = @(
        'Chrome','WhatsApp Desktop','Adobe Acrobat Reader',
        'Visual C++ Redistributable x64','Visual C++ Redistributable x86',
        '.NET Desktop Runtime 8','7-Zip','VLC',
        'Revo Uninstaller','Everything','Microsoft PC Manager',
        'BleachBit','DiskSavvy','Microsoft Teams','Defraggler'
    )
    'Level 3 : Performance' = @(
        'Chrome','WhatsApp Desktop','Adobe Acrobat Reader',
        'Visual C++ Redistributable x64','Visual C++ Redistributable x86',
        '.NET Desktop Runtime 8','7-Zip','VLC',
        'Revo Uninstaller','Everything','Microsoft PC Manager',
        'BleachBit','DiskSavvy','Microsoft Teams','Defraggler',
        'HWiNFO','CPU-Z','GPU-Z','CrystalDiskInfo',
        'CrystalDiskMark','Snappy Driver Installer Origin'
    )
    'Level 4 : Gaming' = @(
        'Chrome','WhatsApp Desktop','Adobe Acrobat Reader',
        'Visual C++ Redistributable x64','Visual C++ Redistributable x86',
        '.NET Desktop Runtime 8','7-Zip','VLC',
        'Revo Uninstaller','Everything','Microsoft PC Manager',
        'BleachBit','DiskSavvy','Microsoft Teams','Defraggler',
        'HWiNFO','CPU-Z','GPU-Z','CrystalDiskInfo',
        'CrystalDiskMark','Snappy Driver Installer Origin',
        'Steam','Discord','OBS Studio','MSI Afterburner',
        'NVCleanstall','DDU','Autoruns','Spotify'
    )
}

# ---------------------------------------------------------------------------
# BASIC HELPERS
# ---------------------------------------------------------------------------

function Initialize-Storage {
    New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType File -Path $script:LogPath -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    try {
        Add-Content -LiteralPath $script:LogPath `
            -Value ('{0:u} [{1}] {2}' -f (Get-Date),$Level,$Message) `
            -Encoding UTF8
    } catch {}
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info','Good','Warn','Bad','Accent')]
        [string]$Kind = 'Info'
    )
    $colour = @{
        Info='Gray'; Good='Green'; Warn='Yellow'; Bad='Red'; Accent='Cyan'
    }[$Kind]
    Write-Host "[$($Kind.ToUpper())] $Message" -ForegroundColor $colour
}

function Confirm-Action {
    param(
        [Parameter(Mandatory)][string]$Action,
        [string]$Detail = ''
    )
    Write-Host ''
    Write-Status "About to: $Action" Warn
    if ($Detail) { Write-Host $Detail -ForegroundColor DarkYellow }
    return ((Read-Host 'Continue? (y/n)') -match '^[Yy]$')
}

function Invoke-Safely {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    try {
        & $Action
        Write-Log "$Name completed" SUCCESS
        Write-Status "$Name complete" Good
        return $true
    } catch {
        Write-Log "$Name failed: $($_.Exception.Message)" ERROR
        Write-Status "$Name failed: $($_.Exception.Message)" Bad
        return $false
    }
}

function Show-Title {
    Clear-Host
    Write-Host ''
    Write-Host '  A I C K A R A  W I N  U T I L' -ForegroundColor Green
    Write-Host ''

    $banner=@'
  /$$$$$$  /$$$$$$  /$$$$$$  /$$   /$$  /$$$$$$  /$$$$$$$   /$$$$$$
 /$$__  $$|_  $$_/ /$$__  $$| $$  /$$/ /$$__  $$| $$__  $$ /$$__  $$
| $$  \ $$  | $$  | $$  \__/| $$ /$$/ | $$  \ $$| $$  \ $$| $$  \ $$
| $$$$$$$$  | $$  | $$      | $$$$$/  | $$$$$$$$| $$$$$$$/| $$$$$$$$
| $$__  $$  | $$  | $$      | $$  $$  | $$__  $$| $$__  $$| $$__  $$
| $$  | $$  | $$  | $$    $$| $$\  $$ | $$  | $$| $$  \ $$| $$  | $$
| $$  | $$ /$$$$$$|  $$$$$$/| $$ \  $$| $$  | $$| $$  | $$| $$  | $$
|__/  |__/|______/ \______/ |__/  \__/|__/  |__/|__/  |__/|__/  |__/
'@

    Write-Host $banner -ForegroundColor Green
    Write-Host ''
    Write-Host "  AICKARA UTIL LIGHT v$script:Version" -ForegroundColor DarkGray
    Write-Host ''
}

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Ensure-Elevation {
    if (Test-IsAdmin) { return }
    Write-Status 'Administrator permission is required for these maintenance features.' Warn
    if ((Read-Host 'Restart elevated now? (Y/N)') -notmatch '^[Yy]') {
        throw 'Elevation was declined.'
    }
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process PowerShell -Verb RunAs -ArgumentList $args
    exit
}

function Invoke-ProgressTask {
    param(
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][array]$Steps
    )
    for ($i=0; $i -lt $Steps.Count; $i++) {
        $step=$Steps[$i]
        $percent=[int](($i/[Math]::Max($Steps.Count,1))*100)
        Write-Progress -Activity $Activity -Status $step.Name -PercentComplete $percent
        Write-Status "$($step.Name)... RUNNING" Accent
        if ($step.ContainsKey('Argument')) { & $step.Action $step.Argument } else { & $step.Action }
        Write-Status "$($step.Name)... DONE" Good
    }
    Write-Progress -Activity $Activity -Completed
}

# ---------------------------------------------------------------------------
# PACKAGE OPTIMIZATIONS
# ---------------------------------------------------------------------------

function Set-PowerScheme {
    param([ValidateSet('Balanced','HighPerformance')][string]$Scheme)
    $id=if($Scheme -eq 'Balanced'){
        '381b4222-f694-41f0-9685-ff5bb260df2e'
    } else {
        '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    }
    powercfg /setactive $id
}

function Disable-GameDvrConservatively {
    New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' `
        -Name 'AppCaptureEnabled' -PropertyType DWord -Value 0 -Force | Out-Null
    New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\System\GameConfigStore' `
        -Name 'GameDVR_Enabled' -PropertyType DWord -Value 0 -Force | Out-Null
}

function Invoke-PackageOptimization {
    while ($true) {
        Clear-Host
        Write-Host 'PACKAGE OPTIMIZATIONS' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '1. Level 1 : Office'
        Write-Host '2. Level 2 : Laptop'
        Write-Host '3. Level 3 : Performance'
        Write-Host '4. Level 4 : Gaming'
        Write-Host '5. Custom optimization'
        Write-Host '0. Back to main menu'
        Write-Host ''

        $choice = Read-Host 'Choose'
        if ($choice -eq '0') { return }

        $steps = @()

        if ($choice -in @('1','2','3','4')) {
            $level = [int]$choice
            $steps += @{ Name='Office baseline: Balanced power plan'; Action={ Set-PowerScheme Balanced } }

            if ($level -ge 2) {
                $steps += @{ Name='Laptop baseline: enabling hibernation'; Action={ powercfg /hibernate on } }
            }

            if ($level -ge 3) {
                $steps += @{ Name='Performance plan: High performance'; Action={ Set-PowerScheme HighPerformance } }
            }

            if ($level -ge 4) {
                $steps += @{ Name='Gaming: disabling background Game DVR capture'; Action={ Disable-GameDvrConservatively } }
            }
        }
        elseif ($choice -eq '5') {
            if ((Read-Host 'Use High performance power plan? (Y/N)') -match '^[Yy]$') {
                $steps += @{ Name='High performance power plan'; Action={ Set-PowerScheme HighPerformance } }
            }

            if ((Read-Host 'Enable hibernation? (Y/N)') -match '^[Yy]$') {
                $steps += @{ Name='Enable hibernation'; Action={ powercfg /hibernate on } }
            }

            if ((Read-Host 'Disable Game DVR background capture? (Y/N)') -match '^[Yy]$') {
                $steps += @{ Name='Disable Game DVR'; Action={ Disable-GameDvrConservatively } }
            }
        }
        else {
            Write-Status 'Invalid selection.' Warn
            continue
        }

        if (-not $steps) {
            Write-Status 'No changes selected.' Warn
            continue
        }

        if (Confirm-Action "apply the selected optimization ($($steps.Count) steps)") {
            Invoke-Safely 'Package optimization' {
                Invoke-ProgressTask -Activity 'Applying optimization' -Steps $steps
            } | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------
# CLEANUP
# ---------------------------------------------------------------------------

function Recycle-Bin-Empty {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if($PSCmdlet.ShouldProcess('Recycle Bin','Empty')){
        try{
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Status 'Recycle Bin emptied.' Good
        }catch{
            Write-Log "Empty recycle bin failed: $($_.Exception.Message)" ERROR
            Write-Status "Could not empty Recycle Bin: $($_.Exception.Message)" Bad
        }
    }
}

function Clear-TempFilesExtended {
    param(
        [switch]$IncludeBrowserCaches,
        [switch]$IncludeWindowsUpdateCache
    )

    $targets=@($env:TEMP,"$env:WINDIR\Temp","$env:LOCALAPPDATA\Temp") |
        Where-Object { $_ -and (Test-Path $_) }

    Write-Host ("Found {0} target folders to scan." -f $targets.Count) -ForegroundColor Yellow
    $candidates=foreach($t in $targets){
        Get-ChildItem -LiteralPath $t -Force -File -Recurse -ErrorAction SilentlyContinue
    }

    $count=@($candidates).Count
    $sizeMB=(@($candidates | Measure-Object -Property Length -Sum).Sum/1MB)
    Write-Host ("Candidate files: {0:N0} ({1:N1} MB)" -f $count,$sizeMB) -ForegroundColor Yellow

    if($count -eq 0){
        Write-Status 'No temporary files found.' Info
        return
    }

    if(-not (Confirm-Action 'clean temporary files' ($targets -join [Environment]::NewLine))){return}

    Invoke-Safely 'Extended temp cleanup' {
        $processed=0;$removed=0;$removedBytes=0L
        foreach($f in $candidates){
            $processed++
            try{
                $len=$f.Length
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $removed++
                $removedBytes += $len
            }catch{
                Write-Log "Skipping locked file: $($f.FullName)" WARN
            }
            Write-Progress -Activity 'Clearing temp' -Status $f.Name `
                -PercentComplete ([int](100*$processed/$count))
        }
        Write-Progress -Activity 'Clearing temp' -Completed
        Write-Status ("Removed {0:N0} files ({1:N1} MB)." -f $removed,($removedBytes/1MB)) Good

        if($IncludeWindowsUpdateCache){
            if(Confirm-Action 'Clear Windows Update download cache' 'This removes files in the Windows Update download cache.'){
                try{
                    Stop-Service wuauserv -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath "$env:Windir\SoftwareDistribution\Download\*" `
                        -Recurse -Force -ErrorAction SilentlyContinue
                    Start-Service wuauserv -ErrorAction SilentlyContinue
                }catch{
                    Write-Log "Windows Update cache clear failed: $($_.Exception.Message)" ERROR
                }
            }
        }

        if($IncludeBrowserCaches){
            $browserTargets=@(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                "$env:APPDATA\Mozilla\Firefox\Profiles"
            ) | Where-Object {Test-Path $_}

            foreach($b in $browserTargets){
                if(Confirm-Action "Clear browser cache path $b"){
                    Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } | Out-Null
}

function Invoke-Cleanup {
    while($true){
        Clear-Host
        Write-Host 'CLEANUP' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '1. Quick cleanup (Windows/user temp only)'
        Write-Host '2. Extended cleanup'
        Write-Host '3. Empty Recycle Bin'
        Write-Host '0. Back to main menu'
        Write-Host ''
        $choice=Read-Host 'Choose'

        switch($choice){
            '1' {
                $targets=@($env:TEMP,"$env:WINDIR\Temp") | Where-Object {$_ -and (Test-Path $_)}
                $candidates=foreach($target in $targets){
                    Get-ChildItem -LiteralPath $target -Force -File -Recurse -ErrorAction SilentlyContinue
                }
                $candidateCount=@($candidates).Count
                $candidateSize=(@($candidates|Measure-Object -Property Length -Sum).Sum/1MB)
                Write-Host ("Cleanup found {0:N0} temporary files ({1:N1} MB)." -f $candidateCount,$candidateSize) -ForegroundColor Yellow

                if($candidateCount -gt 0 -and (Confirm-Action 'clean temporary files' ($targets -join [Environment]::NewLine))){
                    Invoke-Safely 'Temporary-file cleanup' {
                        $removed=0;$removedBytes=0L;$processed=0
                        foreach($file in $candidates){
                            $processed++
                            try{
                                $length=$file.Length
                                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                                $removed++
                                $removedBytes += $length
                            }catch{
                                Write-Log "Cleanup skipped locked/protected file: $($file.FullName)" WARN
                            }
                            Write-Progress -Activity 'Cleaning temporary files' -Status $file.Name `
                                -PercentComplete ([int](100*$processed/$candidateCount))
                        }
                        Write-Progress -Activity 'Cleaning temporary files' -Completed
                        Write-Status ("Removed {0:N0} files ({1:N1} MB)." -f $removed,($removedBytes/1MB)) Good
                    } | Out-Null
                }
            }
            '2' {
                $wu=(Read-Host 'Also clear Windows Update download cache? (Y/N)') -match '^[Yy]'
                $browsers=(Read-Host 'Also clear browser caches (Chrome/Edge/Firefox)? (Y/N)') -match '^[Yy]'
                Clear-TempFilesExtended -IncludeWindowsUpdateCache:$wu -IncludeBrowserCaches:$browsers
                if((Read-Host 'Also empty the Recycle Bin? (Y/N)') -match '^[Yy]'){Recycle-Bin-Empty}
            }
            '3' {
                if((Read-Host 'Empty the Recycle Bin? (Y/N)') -match '^[Yy]'){Recycle-Bin-Empty}
            }
            '0' { return }
            default { Write-Status 'Invalid selection.' Warn }
        }
    }
}

# ---------------------------------------------------------------------------
# FIXES / REPAIRS
# ---------------------------------------------------------------------------

function Invoke-SafeRepair {
    [CmdletBinding()]
    param(
        [switch]$RunSFC,
        [switch]$RunDISM,
        [switch]$ResetWinsock,
        [switch]$FlushDNS
    )

    $steps=@()
    if($RunSFC){$steps += @{Name='SFC /scannow';Action={sfc /scannow}}}
    if($RunDISM){$steps += @{Name='DISM RestoreHealth';Action={DISM /Online /Cleanup-Image /RestoreHealth}}}
    if($ResetWinsock){$steps += @{Name='Winsock reset';Action={netsh winsock reset}}}
    if($FlushDNS){$steps += @{Name='Flush DNS';Action={ipconfig /flushdns}}}

    if(-not $steps){
        Write-Status 'No repair steps selected.' Warn
        return
    }

    if(-not (Confirm-Action "Run safe repair steps: $(($steps | ForEach-Object {$_.Name}) -join ', ')")){
        return
    }

    foreach($s in $steps){
        Invoke-Safely $s.Name { & $s.Action } | Out-Null
    }
}

function Invoke-Fixes {
    while($true){
        Clear-Host
        Write-Host 'FIXES / REPAIRS' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '1. Flush DNS cache'
        Write-Host '2. System File Checker'
        Write-Host '3. DISM RestoreHealth'
        Write-Host '4. Full staged repair (SFC + DISM + Winsock + DNS)'
        Write-Host '0. Back to main menu'
        Write-Host ''

        switch(Read-Host 'Choose'){
            '1' {
                if(Confirm-Action 'flush the DNS resolver cache'){
                    Invoke-Safely 'DNS flush' {Clear-DnsClientCache} | Out-Null
                }
            }
            '2' {
                if(Confirm-Action 'run System File Checker' 'This may take several minutes.'){
                    Invoke-Safely 'SFC' {sfc /scannow} | Out-Null
                }
            }
            '3' {
                if(Confirm-Action 'run DISM RestoreHealth' 'This may contact Windows Update.'){
                    Invoke-Safely 'DISM RestoreHealth' {DISM /Online /Cleanup-Image /RestoreHealth} | Out-Null
                }
            }
            '4' {
                Invoke-SafeRepair -RunSFC -RunDISM -ResetWinsock -FlushDNS
            }
            '0' {return}
            default {Write-Status 'Invalid selection.' Warn}
        }
    }
}

# ---------------------------------------------------------------------------
# WINDOWS ACTIVATION
# ---------------------------------------------------------------------------

function Invoke-WindowsActivation {
    Write-Host ''
    Write-Status 'Launching Windows activation utility.' Warn
    if(Confirm-Action 'run the external Windows activation command' 'This uses the activated.win command supplied by the original utility.'){
        irm 'https://get.activated.win/' | iex
    }
}

# ---------------------------------------------------------------------------
# APP INSTALL / UPDATE
# ---------------------------------------------------------------------------

function Get-PackageManager {
    if(Get-Command winget -ErrorAction SilentlyContinue){return 'winget'}
    if(Get-Command choco -ErrorAction SilentlyContinue){return 'choco'}
    return $null
}

function Install-AppItem {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipConfirmation
    )

    if(-not $script:AppCatalog.Contains($Name)){
        Write-Status "Unknown app: $Name" Bad
        return
    }

    $app=$script:AppCatalog[$Name]
    $pm=Get-PackageManager

    if(-not $pm){
        Write-Status 'Winget and Chocolatey were not found. Install one, then try again.' Bad
        return
    }

    if(-not $SkipConfirmation -and -not (Confirm-Action "install or update $Name" "Package manager: $pm")){
        return
    }

    Invoke-Safely "Install or update $Name" {
        if($pm -eq 'winget'){
            $installed=winget list --id $app.Winget -e --accept-source-agreements 2>$null | Out-String
            if($installed -match [regex]::Escape($app.Winget)){
                winget upgrade --id $app.Winget -e --accept-package-agreements --accept-source-agreements
            }else{
                winget install --id $app.Winget -e --accept-package-agreements --accept-source-agreements
            }
        }else{
            if($app.Choco -eq 'na'){
                throw "$Name is available through Winget only. Install App Installer/Winget, then try again."
            }
            choco upgrade $app.Choco -y
        }
    } | Out-Null
}

function Install-AppList {
    param(
        [Parameter(Mandatory)][string[]]$Apps,
        [Parameter(Mandatory)][string]$Activity
    )

    $total=$Apps.Count
    for($i=0;$i -lt $total;$i++){
        $app=$Apps[$i]
        Write-Progress -Activity $Activity `
            -Status "Installing $app ($($i+1) of $total)" `
            -PercentComplete ([int](100*$i/[Math]::Max($total,1)))
        Write-Status "[$($i+1)/$total] Installing or updating $app..." Info
        Install-AppItem -Name $app -SkipConfirmation
    }
    Write-Progress -Activity $Activity -Completed
}

function Install-AppBundle {
    param([Parameter(Mandatory)][string]$BundleName)
    $apps=$script:AppBundles[$BundleName]
    if(Confirm-Action "install or update the $BundleName app package" ($apps -join ', ')){
        Install-AppList -Apps $apps -Activity "App package: $BundleName"
    }
}

function Install-OrUpdate-App {
    while($true){
        Clear-Host
        Write-Host 'APP INSTALL / UPDATE' -ForegroundColor Cyan
        Write-Host ''
        $index=1
        foreach($bundle in $script:AppBundles.Keys){
            Write-Host "$index. $bundle"
            $index++
        }
        Write-Host "$index. Custom app selection"
        Write-Host "$($index+1). Browse by category"
        Write-Host '0. Back to main menu'
        Write-Host ''

        $pick=Read-Host 'Choose'
        if($pick -eq '0'){return}

        $parsed=0
        $isNumber=[int]::TryParse($pick,[ref]$parsed)

        if($isNumber -and $parsed -ge 1 -and $parsed -lt $index){
            Install-AppBundle -BundleName @($script:AppBundles.Keys)[$parsed-1]
            continue
        }

        if($isNumber -and $parsed -eq $index){
            while($true){
                Clear-Host
                Write-Host 'CUSTOM APP INSTALL / UPDATE' -ForegroundColor Cyan
                Write-Host ''
                $n=1;$lookup=@{}

                foreach($name in $script:AppCatalog.Keys){
                    $lookup[$n]=$name
                    $app=$script:AppCatalog[$name]
                    Write-Host ("{0,2}. {1}  [{2}]" -f $n,$name,$app.Category)
                    $n++
                }

                Write-Host ''
                Write-Host '0. Back'
                $selected=(Read-Host 'Enter app numbers separated by commas') -split ',' |
                    ForEach-Object {
                        $v=0
                        if([int]::TryParse($_.Trim(),[ref]$v) -and $lookup.ContainsKey($v)){
                            $lookup[$v]
                        }
                    } | Select-Object -Unique

                if(-not $selected){
                    if((Read-Host 'No apps selected. Press Enter to continue or 0 to go back') -eq '0'){break}
                    continue
                }

                if(Confirm-Action 'install or update selected apps' ($selected -join ', ')){
                    Install-AppList -Apps $selected -Activity 'Selected apps'
                }
            }
            continue
        }

        if($isNumber -and $parsed -eq ($index+1)){
            while($true){
                Clear-Host
                Write-Host 'APP CATEGORIES' -ForegroundColor Cyan
                Write-Host ''
                $categories=@($script:AppCatalog.Values | ForEach-Object {$_.Category} | Sort-Object -Unique)
                $c=1;$catMap=@{}
                foreach($cat in $categories){
                    $catMap[$c]=$cat
                    Write-Host "$c. $cat"
                    $c++
                }
                Write-Host '0. Back'
                $catPick=Read-Host 'Choose category'
                if($catPick -eq '0'){break}

                $catNum=0
                if(-not [int]::TryParse($catPick,[ref]$catNum) -or -not $catMap.ContainsKey($catNum)){
                    Write-Status 'Invalid selection.' Warn
                    continue
                }

                $chosenCategory=$catMap[$catNum]
                while($true){
                    Clear-Host
                    Write-Host "$chosenCategory" -ForegroundColor Cyan
                    Write-Host ''
                    $names=@($script:AppCatalog.Keys | Where-Object {$script:AppCatalog[$_].Category -eq $chosenCategory})
                    $lookup=@{};$n=1
                    foreach($name in $names){
                        $lookup[$n]=$name
                        Write-Host "$n. $name"
                        $n++
                    }
                    Write-Host '0. Back'
                    $appPick=Read-Host 'Choose app number'
                    if($appPick -eq '0'){break}

                    $appNum=0
                    if([int]::TryParse($appPick,[ref]$appNum) -and $lookup.ContainsKey($appNum)){
                        Install-AppItem -Name $lookup[$appNum]
                    }else{
                        Write-Status 'Invalid selection.' Warn
                    }
                }
            }
            continue
        }

        Write-Status 'Invalid selection.' Warn
    }
}

# ---------------------------------------------------------------------------
# DIAGNOSTICS
# ---------------------------------------------------------------------------

function Get-HardwareInfo {
    try{
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu=Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $logical=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue
        $gpu=Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            ComputerName=$env:COMPUTERNAME
            Manufacturer=$cs.Manufacturer
            Model=$cs.Model
            CPU=$cpu.Name
            Cores=$cpu.NumberOfCores
            LogicalProcessors=$cpu.NumberOfLogicalProcessors
            TotalPhysicalMemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2)
            Disks=$logical | Select-Object DeviceID,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}}
            GPU=($gpu.Name -join ', ')
            OS=$os.Caption
        }
    }catch{
        Write-Log "Get-HardwareInfo failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Get-StartupAnalysis {
    $results=@()
    $runKeys=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach($k in $runKeys){
        try{
            $items=Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
            if($items){
                foreach($p in $items.PSObject.Properties){
                    if($p.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider'){continue}
                    $exe=$p.Value -as [string]
                    $flag=if($exe -match '\.exe'){'LikelyExe'}else{'Unknown'}
                    $results += [PSCustomObject]@{
                        Source='Registry';Location=$k;Name=$p.Name;Command=$exe;Flag=$flag
                    }
                }
            }
        }catch{}
    }

    $folders=@(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    )

    foreach($folder in $folders){
        if(Test-Path $folder){
            Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $results += [PSCustomObject]@{
                        Source='Startup Folder';Location=$folder;Name=$_.Name;Command=$_.FullName;Flag='StartupItem'
                    }
                }
        }
    }

    return $results
}

function Invoke-Diagnostics {
    while($true){
        Clear-Host
        Write-Host 'DIAGNOSE / SYSTEM RECON' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '1. Hardware / system information'
        Write-Host '2. Startup programs'
        Write-Host '3. Full system recon'
        Write-Host '0. Back to main menu'
        Write-Host ''

        switch(Read-Host 'Choose'){
            '1' {
                $info=Get-HardwareInfo
                if($info){
                    Write-Host ''
                    $info | Format-List ComputerName,Manufacturer,Model,CPU,Cores,LogicalProcessors,TotalPhysicalMemoryGB,GPU,OS | Out-Host
                    Write-Host 'DISKS' -ForegroundColor Cyan
                    $info.Disks | Format-Table -AutoSize | Out-Host
                }
            }
            '2' {
                Get-StartupAnalysis | Format-Table Source,Name,Command,Flag -AutoSize | Out-Host
            }
            '3' {
                try{
                    $os=Get-CimInstance Win32_OperatingSystem
                    $cs=Get-CimInstance Win32_ComputerSystem
                    $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
                    $gpu=Get-CimInstance Win32_VideoController | Select-Object -First 1
                    $uptime=(Get-Date)-$os.LastBootUpTime

                    Write-Host "HOST         : $($cs.Name)"
                    Write-Host "OS           : $($os.Caption) (Build $($os.BuildNumber))"
                    Write-Host "CPU          : $($cpu.Name.Trim())"
                    Write-Host "RAM          : $([Math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB"
                    Write-Host "GPU          : $($gpu.Name)"
                    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
                        ForEach-Object {
                            Write-Host "DISK $($_.DeviceID) : $([Math]::Round($_.FreeSpace/1GB,1)) GB free / $([Math]::Round($_.Size/1GB,1)) GB"
                        }
                    Write-Host "UPTIME       : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
                }catch{
                    Write-Status "System recon failed: $($_.Exception.Message)" Warn
                }
            }
            '0' {return}
            default {Write-Status 'Invalid selection.' Warn}
        }
    }
}

# ---------------------------------------------------------------------------
# NETWORK
# ---------------------------------------------------------------------------

function Get-ActiveNetworkAdapter {
    try{
        $interfaces=Get-NetIPInterface -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {$_.ConnectionState -eq 'Connected'} |
            Sort-Object InterfaceMetric
        if(-not $interfaces){return $null}
        return $interfaces[0].InterfaceAlias
    }catch{
        Write-Log "Get-ActiveNetworkAdapter failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Get-DnsSettings {
    param([string]$Adapter)
    try{
        if($Adapter){
            $addrs=Get-DnsClientServerAddress -InterfaceAlias $Adapter -AddressFamily IPv4 -ErrorAction Stop
            return [PSCustomObject]@{
                Adapter=$Adapter
                ServerAddresses=($addrs.ServerAddresses -join ', ')
            }
        }

        $all=Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop
        return @($all | ForEach-Object {
            [PSCustomObject]@{
                Adapter=$_.InterfaceAlias
                ServerAddresses=($_.ServerAddresses -join ', ')
            }
        })
    }catch{
        Write-Log "Get-DnsSettings failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Set-DnsServers {
    param(
        [ValidateSet('Cloudflare','Google','DHCP','Custom')]
        [string]$Preset,
        [string[]]$Servers
    )

    $adapter=Get-ActiveNetworkAdapter
    if(-not $adapter){
        Write-Status 'No active IPv4 network adapter found.' Bad
        return
    }

    $addresses=switch($Preset){
        'Cloudflare' { @('1.1.1.1','1.0.0.1') }
        'Google'     { @('8.8.8.8','8.8.4.4') }
        'DHCP'       { $null }
        'Custom'     { $Servers }
    }

    if($Preset -eq 'Custom' -and (-not $addresses)){
        Write-Status 'No DNS servers supplied.' Bad
        return
    }

    if(-not (Confirm-Action "change DNS on adapter '$adapter'" "Preset: $Preset")){
        return
    }

    Invoke-Safely "Set DNS: $Preset" {
        if($Preset -eq 'DHCP'){
            Set-DnsClientServerAddress -InterfaceAlias $adapter -ResetServerAddresses -ErrorAction Stop
        }else{
            Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $addresses -ErrorAction Stop
        }
    } | Out-Null
}

function Test-NetworkDiagnostics {
    param([string]$TargetHost='8.8.8.8')

    $outDir = Join-Path $script:DataRoot 'Diagnostics'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $report = Join-Path $outDir ('network-report_{0:yyyyMMdd_HHmmss}.txt' -f (Get-Date))
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("Network diagnostics report: $TargetHost")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format 'u')")

    [void]$sb.AppendLine('--- Ping ---')
    try {
        $pingOutput = Test-Connection -ComputerName $TargetHost -Count 4 -ErrorAction Stop | Out-String
        [void]$sb.AppendLine($pingOutput)
    }
    catch {
        [void]$sb.AppendLine("Ping failed: $($_.Exception.Message)")
    }

    [void]$sb.AppendLine('--- Traceroute ---')
    try {
        $traceOutput = tracert -d $TargetHost | Out-String
        [void]$sb.AppendLine($traceOutput)
    }
    catch {
        [void]$sb.AppendLine('Traceroute failed')
    }

    [void]$sb.AppendLine('--- DNS resolution ---')
    try {
        $dnsOutput = Resolve-DnsName -Name $TargetHost -ErrorAction Stop | Out-String
        [void]$sb.AppendLine($dnsOutput)
    }
    catch {
        [void]$sb.AppendLine('DNS lookup failed or Resolve-DnsName unavailable')
    }

    [void]$sb.AppendLine('--- Port checks ---')
    foreach ($port in @(53,80,443,3389)) {
        $res = Test-NetConnection -ComputerName $TargetHost -Port $port -WarningAction SilentlyContinue
        [void]$sb.AppendLine("Port ${port}: TcpTestSucceeded=$($res.TcpTestSucceeded) | RemoteAddress=$($res.RemoteAddress)")
    }

    $sb.ToString() | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Log "Network report saved to $report" INFO
    Write-Status "Network report saved: $report" Good
    return $report
}

function Invoke-AdvancedNetwork {
    while($true){
        Clear-Host
        Write-Host 'ADVANCED NETWORK TOOLS' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '1. Display IP configuration'
        Write-Host '2. Test a host'
        Write-Host '3. Flush DNS cache'
        Write-Host '4. View current DNS servers'
        Write-Host '5. Set DNS servers'
        Write-Host '6. Run full network diagnostics report'
        Write-Host '0. Back to main menu'
        Write-Host ''

        $choice = Read-Host 'Choose'

        switch($choice){
            '1' {ipconfig /all}
            '2' {
                $hostName=Read-Host 'Host name or IP'
                if($hostName){Test-Connection $hostName -Count 4}
            }
            '3' {
                if(Confirm-Action 'flush the DNS resolver cache'){
                    Invoke-Safely 'DNS flush' {Clear-DnsClientCache} | Out-Null
                }
            }
            '4' {
                $dns=Get-DnsSettings
                if($dns){$dns | Format-Table -AutoSize | Out-Host}
            }
            '5' {
                Write-Host '1. Cloudflare (1.1.1.1)'
                Write-Host '2. Google (8.8.8.8)'
                Write-Host '3. DHCP (automatic)'
                Write-Host '4. Custom'
                switch(Read-Host 'Choose 1-4'){
                    '1' {Set-DnsServers -Preset Cloudflare}
                    '2' {Set-DnsServers -Preset Google}
                    '3' {Set-DnsServers -Preset DHCP}
                    '4' {
                        $servers=(Read-Host 'Enter DNS server(s), comma separated') -split ',' |
                            ForEach-Object {$_.Trim()} | Where-Object {$_}
                        Set-DnsServers -Preset Custom -Servers $servers
                    }
                    default {Write-Status 'Invalid selection.' Warn}
                }
            }
            '6' {
                $target=Read-Host 'Host/IP (Enter for 8.8.8.8)'
                if(-not $target){$target='8.8.8.8'}
                Test-NetworkDiagnostics -TargetHost $target | Out-Null
            }
            '0' {return}
            default {Write-Status 'Invalid selection.' Warn}
        }
    }
}

# ---------------------------------------------------------------------------
# MAIN MENU
# ---------------------------------------------------------------------------

function Show-MainMenu {
    $firstMenuDisplay = $true

    while(-not $script:Cancelled){
        if(-not $firstMenuDisplay){
            Clear-Host
        }
        $firstMenuDisplay = $false

        Write-Host '==================== MAIN MENU ====================' -ForegroundColor Green
        Write-Host ' 1) Package Optimizations'
        Write-Host ' 2) Cleanup'
        Write-Host ' 3) Fixes / Repairs'
        Write-Host ' 4) Activate Windows'
        Write-Host ' 5) Install / Update Apps'
        Write-Host ' 6) Diagnose / System Recon'
        Write-Host ' 7) Advanced Network Tools'
        Write-Host ' 8) Exit'
        Write-Host '=====================================================' -ForegroundColor Green
        Write-Host ''
        $choice=Read-Host 'Select'

        switch($choice){
            '1' {Invoke-PackageOptimization}
            '2' {Invoke-Cleanup}
            '3' {Invoke-Fixes}
            '4' {Invoke-WindowsActivation}
            '5' {Install-OrUpdate-App}
            '6' {Invoke-Diagnostics}
            '7' {Invoke-AdvancedNetwork}
            '8' {$script:Cancelled=$true}
            default {Write-Status 'Invalid selection.' Warn}
        }
    }
}

# ---------------------------------------------------------------------------
# START
# ---------------------------------------------------------------------------

try{
    Initialize-Storage
    Ensure-Elevation
    Show-Title
    Show-MainMenu
}
catch{
    Write-Log "Fatal error: $($_.Exception.Message)" ERROR
    Write-Host ''
    Write-Status "Stopped safely: $($_.Exception.Message)" Bad
    Write-Host ''
}
finally{
    Write-Log 'AICKARA UTIL LIGHT session ended.' INFO
    Write-Host ''
    Write-Host 'AICKARA UTIL LIGHT closed.' -ForegroundColor Cyan
}
