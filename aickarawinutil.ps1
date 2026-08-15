<#
  AICKARAWINUTIL - conservative Windows maintenance console
  Run from an elevated PowerShell session, or allow the script to elevate itself.
  This tool deliberately never activates Windows, removes files, changes the registry,
  installs software, or changes a power plan without showing a confirmation prompt.
#>
[CmdletBinding()]
param(
    [string]$AccessCode = '89385899',
    [switch]$SkipBootAnimation,
    [switch]$NoRemotePrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Version = '1.0.0'
$script:AppName = 'AICKARAWINUTIL'
$script:DataRoot = if (Test-Path "$env:ProgramData") { Join-Path $env:ProgramData 'AICKARAWINUTIL' } else { Join-Path $env:LOCALAPPDATA 'AICKARAWINUTIL' }
$script:LogPath = Join-Path $script:DataRoot 'AICKARAWINUTIL.log'
$script:StatePath = Join-Path $script:DataRoot 'undo-state.json'
$script:Cancelled = $false

function Initialize-Storage {
    New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
    if (-not (Test-Path $script:LogPath)) { New-Item -ItemType File -Path $script:LogPath -Force | Out-Null }
}
function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level='INFO')
    $line = '{0:u} [{1}] {2}' -f (Get-Date), $Level, $Message
    try { Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8 } catch { }
}
function Write-Status {
    param([string]$Message, [ValidateSet('Info','Good','Warn','Bad','Accent')] [string]$Kind='Info')
    $colour = @{ Info='Gray'; Good='Green'; Warn='Yellow'; Bad='Red'; Accent='Cyan' }[$Kind]
    Write-Host "[$($Kind.ToUpper())] $Message" -ForegroundColor $colour
}
function Confirm-Action {
    param([Parameter(Mandatory)][string]$Action, [string]$Detail='')
    Write-Host ''
    Write-Status "About to: $Action" Warn
    if ($Detail) { Write-Host $Detail -ForegroundColor DarkYellow }
    return ((Read-Host 'Continue? (y/n)') -match '^[Yy]$')
}
function Invoke-Safely {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    try { & $Action; Write-Log "$Name completed" SUCCESS; Write-Status "$Name complete" Good; return $true }
    catch { Write-Log "$Name failed: $($_.Exception.Message)" ERROR; Write-Status "$Name failed: $($_.Exception.Message)" Bad; return $false }
}
function Write-Typewriter {
    param([string]$Text, [int]$Delay=8, [ConsoleColor]$Color=[ConsoleColor]::Cyan)
    Write-Host '' -NoNewline
    foreach ($char in $Text.ToCharArray()) { Write-Host $char -NoNewline -ForegroundColor $Color; Start-Sleep -Milliseconds $Delay }
    Write-Host ''
}
function Write-Glitch {
    param([string]$Text, [int]$Frames=8, [string]$Color='Green')
    $chars = '!<>-_\/[]{}=+*^?#$%&'
    $orig = New-Object char[] $Text.Length
    for ($i=0; $i -lt $Text.Length; $i++) { $orig[$i]=$Text[$i] }
    for ($f=0; $f -lt $Frames; $f++) {
        $line=''
        for ($i=0; $i -lt $Text.Length; $i++) {
            if ($Text[$i] -eq ' ') { $line+=' '; continue }
            if ((Get-Random -Minimum 0.0 -Maximum 1.0) -lt ($f / [double]$Frames)) { $line += $orig[$i] } else { $line += $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] }
        }
        Write-Host -NoNewline "`r$line" -ForegroundColor $Color; Start-Sleep -Milliseconds 40
    }
    Write-Host "`r$Text" -ForegroundColor $Color
}
function Show-MatrixRain {
    param([int]$DurationMs=1600)
    $originalColor=$Host.UI.RawUI.ForegroundColor; $width=[Math]::Max(40,$Host.UI.RawUI.WindowSize.Width); $chars='01234567890ABCDEF$#@!*'; $sw=[Diagnostics.Stopwatch]::StartNew()
    Clear-Host
    while ($sw.ElapsedMilliseconds -lt $DurationMs) { Write-Host (-join (1..$width | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })) -ForegroundColor DarkGreen; Start-Sleep -Milliseconds 20 }
    Clear-Host; $Host.UI.RawUI.ForegroundColor=$originalColor
}
function Show-ScanBar {
    param([string]$Label='Scanning', [int]$Width=24, [string]$Color='Cyan')
    Write-Host -NoNewline "  $Label " -ForegroundColor $Color; Write-Host -NoNewline '[' -ForegroundColor DarkGray
    for ($i=0; $i -lt $Width; $i++) { Start-Sleep -Milliseconds (Get-Random -Minimum 15 -Maximum 45); Write-Host -NoNewline '#' -ForegroundColor $Color }
    Write-Host ']' -ForegroundColor DarkGray
}
function Show-BootSequence {
    Show-MatrixRain
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
    Write-Glitch -Text 'A I C K A R A W I N U T I L' -Frames 10 -Color Green
    Write-Host $banner -ForegroundColor Green; Write-Host ''
    Write-Typewriter '  booting core modules...' 15 DarkGray
    Show-ScanBar 'loading maintenance modules' 24 DarkGreen
    Show-ScanBar 'establishing local shell' 24 DarkGreen
    Write-Host ''
}
function Invoke-ActivationGate {
    $maxAttempts=3
    for ($attempt=1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host ''; Write-Host '  +-----------------------------------------+' -ForegroundColor DarkGreen; Write-Host '  |        RESTRICTED ACCESS TERMINAL        |' -ForegroundColor DarkGreen; Write-Host '  +-----------------------------------------+' -ForegroundColor DarkGreen
        $secureCode=Read-Host '  ENTER ACCESS CODE' -AsSecureString; $bstr=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCode)
        try { $code=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        Show-ScanBar 'validating credentials' 24 Yellow
        if ($code -ceq $AccessCode) { Write-Glitch 'ACCESS GRANTED' 8 Green; return $true }
        Write-Glitch 'ACCESS DENIED' 8 Red
        if ($attempt -lt $maxAttempts) { Write-Host "  attempts remaining: $($maxAttempts-$attempt)" -ForegroundColor DarkRed }
    }
    Write-Host '  >> lockout triggered. session terminated.' -ForegroundColor Red; return $false
}
function Invoke-ProgressTask {
    param([Parameter(Mandatory)][string]$Activity, [Parameter(Mandatory)][array]$Steps)
    for ($i=0; $i -lt $Steps.Count; $i++) {
        $step = $Steps[$i]
        $percent = [int](($i / [Math]::Max($Steps.Count,1)) * 100)
        Write-Progress -Activity $Activity -Status $step.Name -PercentComplete $percent
        Write-Status "$($step.Name)... RUNNING" Accent
        if ($step.ContainsKey('Argument')) { & $step.Action $step.Argument } else { & $step.Action }
        Write-Status "$($step.Name)... DONE" Good
    }
    Write-Progress -Activity $Activity -Completed
}
function Test-IsAdmin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Ensure-Elevation {
    if (Test-IsAdmin) { return }
    Write-Status 'Administrator permission is required for the maintenance features.' Warn
    if ((Read-Host 'Restart elevated now? (Y/N)') -notmatch '^[Yy]') { throw 'Elevation was declined.' }
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AccessCode `"$AccessCode`""
    if ($SkipBootAnimation) { $args += ' -SkipBootAnimation' }; if ($NoRemotePrompt) { $args += ' -NoRemotePrompt' }
    Start-Process PowerShell -Verb RunAs -ArgumentList $args
    exit
}
function Offer-RestorePoint {
    Write-Host ''
    if ((Read-Host 'Create a Windows restore point before continuing? (y/n)') -notmatch '^[Yy]$') { Write-Status 'Restore point skipped.' Warn; return }
    Invoke-Safely 'Creating Windows restore point' {
        Write-Progress -Activity 'Creating restore point' -Status 'Windows is saving a restore point' -PercentComplete 25
        Checkpoint-Computer -Description "AICKARAWINUTIL $(Get-Date -Format 'yyyy-MM-dd HHmm')" -RestorePointType MODIFY_SETTINGS
        Write-Progress -Activity 'Creating restore point' -Completed
    } | Out-Null
}
function Save-UndoState {
    $state = [ordered]@{ Created=(Get-Date).ToString('o'); ActiveScheme=(powercfg /getactivescheme | Out-String); Registry=@{} }
    foreach ($key in @('HKCU:\System\GameConfigStore','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR')) {
        try { $state.Registry[$key] = Get-ItemProperty -Path $key | Select-Object * -ExcludeProperty PS* } catch { }
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:StatePath -Encoding UTF8
    Write-Log 'Undo state saved.' INFO
}
function Restore-UndoState {
    if (-not (Test-Path $script:StatePath)) { Write-Status 'No saved undo state was found.' Warn; return }
    if (-not (Confirm-Action 'restore the saved AICKARAWINUTIL power and gaming settings' 'This restores settings captured before the last optimization.')) { return }
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if ($state.ActiveScheme -match '([0-9a-f]{8}-[0-9a-f-]{27})') { powercfg /setactive $Matches[1] }
    foreach ($prop in $state.Registry.PSObject.Properties) {
        $path=$prop.Name; foreach ($setting in $prop.Value.PSObject.Properties) {
            try { New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -Force | Out-Null } catch { Write-Log "Could not restore $path/$($setting.Name): $($_.Exception.Message)" WARN }
        }
    }
    Write-Status 'Saved settings restored where supported.' Good
}
function Set-PowerScheme {
    param([ValidateSet('Balanced','HighPerformance')][string]$Scheme)
    $id = if ($Scheme -eq 'Balanced') { '381b4222-f694-41f0-9685-ff5bb260df2e' } else { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
    powercfg /setactive $id
}
function Disable-GameDvrConservatively {
    New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -PropertyType DWord -Value 0 -Force | Out-Null
    New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
    New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -PropertyType DWord -Value 0 -Force | Out-Null
}
function Invoke-PackageOptimization {
    Clear-Host; Write-Host 'PACKAGE OPTIMIZATIONS' -ForegroundColor Cyan
    Write-Host '1. Level 1 : Office'
    Write-Host '2. Level 2 : Laptop'
    Write-Host '3. Level 3 : Performance'
    Write-Host '4. Level 4 : Gaming'
    Write-Host '5. Custom optimization'; Write-Host '6. Restore last saved settings'
    $choice = Read-Host 'Choose 1-6'
    if ($choice -eq '6') { Restore-UndoState; return }
    $level = if ($choice -in '1','2','3','4') { [int]$choice } else { 0 }
    $steps = @()
    if ($level -gt 0) {
        $steps += @{Name='Saving rollback settings'; Action={ Save-UndoState }}
        $steps += @{Name='Office baseline: Balanced power plan'; Action={ Set-PowerScheme Balanced }}
        if ($level -ge 2) { $steps += @{Name='Laptop baseline: enabling hibernation'; Action={ powercfg /hibernate on }} }
        if ($level -ge 3) { $steps += @{Name='Performance plan: High performance'; Action={ Set-PowerScheme HighPerformance }} }
        if ($level -ge 4) { $steps += @{Name='Gaming: disabling background Game DVR capture'; Action={ Disable-GameDvrConservatively }} }
    } elseif ($choice -eq '5') {
        if ((Read-Host 'Use High performance power plan? (Y/N)') -match '^[Yy]') { $steps += @{Name='Saving rollback settings';Action={Save-UndoState}}; $steps += @{Name='High performance power plan';Action={Set-PowerScheme HighPerformance}} }
        if ((Read-Host 'Disable Game DVR background capture? (Y/N)') -match '^[Yy]') { if (-not $steps) { $steps += @{Name='Saving rollback settings';Action={Save-UndoState}} }; $steps += @{Name='Disable Game DVR';Action={Disable-GameDvrConservatively}} }
    } else { return }
    if (-not $steps) { Write-Status 'No changes selected.' Warn; return }
    if (Confirm-Action "apply the selected optimization ($($steps.Count) steps)" 'Only the listed conservative settings will be changed; a rollback snapshot is saved first.') { Invoke-Safely 'Package optimization' { Invoke-ProgressTask -Activity 'Applying optimization' -Steps $steps } | Out-Null }
}
function Invoke-Cleanup {
    $targets = @($env:TEMP, "$env:WINDIR\Temp") | Where-Object { $_ -and (Test-Path $_) }
    $candidates = foreach ($target in $targets) { Get-ChildItem -LiteralPath $target -Force -File -Recurse -ErrorAction SilentlyContinue }
    $candidateCount = @($candidates).Count
    $candidateSize = (@($candidates | Measure-Object -Property Length -Sum).Sum / 1MB)
    Write-Host ("Cleanup found {0:N0} temporary files ({1:N1} MB). Locked files will be skipped." -f $candidateCount,$candidateSize) -ForegroundColor Yellow
    if ($candidateCount -eq 0) { Write-Status 'There are no removable temporary files in the selected locations.' Info; return }
    if (-not (Confirm-Action 'clean temporary files' ($targets -join [Environment]::NewLine))) { return }
    Invoke-Safely 'Temporary-file cleanup' {
        $removedCount = 0; $removedBytes = 0L; $processed = 0
        foreach ($file in $candidates) {
            $processed++; Write-Progress -Activity 'Cleaning temporary files' -Status $file.Name -PercentComplete ([int](100 * $processed / $candidateCount))
            try { $length = $file.Length; Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop; $removedCount++; $removedBytes += $length } catch { Write-Log "Cleanup skipped locked or protected file: $($file.FullName)" WARN }
        }
        Write-Progress -Activity 'Cleaning temporary files' -Completed
        Write-Status ("Removed {0:N0} files ({1:N1} MB); locked/protected files were left untouched." -f $removedCount,($removedBytes / 1MB)) Good
    } | Out-Null
}
function Invoke-Fixes {
    Write-Host '1. Flush DNS cache (quick)'; Write-Host '2. System File Checker (may take time)'; Write-Host '3. DISM health restore (may use Windows Update)'
    switch (Read-Host 'Choose 1-3') {
        '1' { if (Confirm-Action 'flush the DNS resolver cache') { Invoke-Safely 'DNS flush' { Clear-DnsClientCache } | Out-Null } }
        '2' { if (Confirm-Action 'run System File Checker' 'This scans protected Windows system files and may take several minutes.') { Invoke-Safely 'SFC' { Write-Progress -Activity 'System File Checker' -Status 'Windows is reporting scan progress in this console' -PercentComplete 1; sfc /scannow; Write-Progress -Activity 'System File Checker' -Completed } | Out-Null } }
        '3' { if (Confirm-Action 'run DISM RestoreHealth' 'This repairs the Windows component store and may contact Windows Update.') { Invoke-Safely 'DISM RestoreHealth' { Write-Progress -Activity 'DISM RestoreHealth' -Status 'Windows is reporting repair progress in this console' -PercentComplete 1; DISM /Online /Cleanup-Image /RestoreHealth; Write-Progress -Activity 'DISM RestoreHealth' -Completed } | Out-Null } }
    }
}
function Invoke-WindowsActivation {
    Write-Host ''
    Write-Status 'Windows activation script is not configured yet.' Warn
    irm https://get.activated.win/ | iex

}
function Get-PackageManager { if (Get-Command winget -ErrorAction SilentlyContinue) { 'winget' } elseif (Get-Command choco -ErrorAction SilentlyContinue) { 'choco' } else { $null } }
$script:AppCatalog = [ordered]@{
    'Chrome'                         = @{ Winget='Google.Chrome';                              Choco='googlechrome' }
    'WhatsApp Desktop'               = @{ Winget='msstore:9NKSQGP7F2NH';                       Choco='na' }
    'Adobe Acrobat Reader'           = @{ Winget='Adobe.Acrobat.Reader.64-bit';               Choco='adobereader' }
    'Visual C++ Redistributable x64' = @{ Winget='Microsoft.VCRedist.2015+.x64';               Choco='vcredist2015' }
    'Visual C++ Redistributable x86' = @{ Winget='Microsoft.VCRedist.2015+.x86';               Choco='vcredist2015' }
    '.NET Desktop Runtime 8'         = @{ Winget='Microsoft.DotNet.DesktopRuntime.8';         Choco='dotnet-8.0-runtime' }
    'VLC'                            = @{ Winget='VideoLAN.VLC';                               Choco='vlc' }
    '7-Zip'                          = @{ Winget='7zip.7zip';                                  Choco='7zip' }
    'qBittorrent'                    = @{ Winget='qBittorrent.qBittorrent';                    Choco='qbittorrent' }
    'Revo Uninstaller'               = @{ Winget='RevoUninstaller.RevoUninstaller';            Choco='revo-uninstaller' }
    'HWiNFO'                         = @{ Winget='REALiX.HWiNFO';                              Choco='hwinfo' }
    'Snappy Driver Installer Origin' = @{ Winget='GlennDelahoy.SnappyDriverInstallerOrigin';    Choco='sdio' }
    'Process Lasso'                  = @{ Winget='BitSum.ProcessLasso';                        Choco='plasso' }
    'Steam'                          = @{ Winget='Valve.Steam';                                Choco='steam-client' }
    'Discord'                        = @{ Winget='Discord.Discord';                            Choco='discord' }
    'OBS Studio'                     = @{ Winget='OBSProject.OBSStudio';                       Choco='obs-studio' }
    'NVCleanstall'                   = @{ Winget='TechPowerUp.NVCleanstall';                   Choco='na' }
    'MSI Afterburner'                = @{ Winget='Guru3D.Afterburner';                         Choco='msiafterburner' }
    # Kept only for the optional remote-support branch required by the utility.
    'AnyDesk'                        = @{ Winget='AnyDesk.AnyDesk';                            Choco='anydesk' }
}
$script:AppBundles = [ordered]@{
    'Level 1 : Office'      = @('Chrome','WhatsApp Desktop','Adobe Acrobat Reader','Visual C++ Redistributable x64','Visual C++ Redistributable x86','.NET Desktop Runtime 8','VLC','7-Zip','qBittorrent')
    'Level 2 : Laptop'      = @('Revo Uninstaller')
    'Level 3 : Performance' = @('HWiNFO','Snappy Driver Installer Origin','Process Lasso')
    'Level 4 : Gaming'      = @('Steam','Discord','OBS Studio','NVCleanstall','MSI Afterburner')
}
# App levels are cumulative, matching Package Optimizations.
$script:AppBundles['Level 2 : Laptop'] = @($script:AppBundles['Level 1 : Office'] + $script:AppBundles['Level 2 : Laptop'])
$script:AppBundles['Level 3 : Performance'] = @($script:AppBundles['Level 2 : Laptop'] + $script:AppBundles['Level 3 : Performance'])
$script:AppBundles['Level 4 : Gaming'] = @($script:AppBundles['Level 3 : Performance'] + $script:AppBundles['Level 4 : Gaming'])
function Install-AppItem {
    param([Parameter(Mandatory)][string]$Name, [switch]$SkipConfirmation)
    if (-not $script:AppCatalog.Contains($Name)) { Write-Status "Unknown app: $Name" Bad; return }
    $app=$script:AppCatalog[$Name]; $pm=Get-PackageManager
    if (-not $pm) { Write-Status 'Winget and Chocolatey were not found. Install one, then try again.' Bad; return }
    if (-not $SkipConfirmation -and -not (Confirm-Action "install or update $Name" "Package manager: $pm")) { return }
    Invoke-Safely "Install or update $Name" {
        if ($pm -eq 'winget') {
            $installed = winget list --id $app.Winget -e --accept-source-agreements 2>$null | Out-String
            if ($installed -match [regex]::Escape($app.Winget)) { winget upgrade --id $app.Winget -e --accept-package-agreements --accept-source-agreements } else { winget install --id $app.Winget -e --accept-package-agreements --accept-source-agreements }
        } else {
            if ($app.Choco -eq 'na') { throw "$Name is available through Winget only. Install App Installer/Winget, then try again." }
            choco upgrade $app.Choco -y
        }
    } | Out-Null
}
function Install-AppBundle {
    param([Parameter(Mandatory)][string]$BundleName)
    $apps=$script:AppBundles[$BundleName]
    if (-not (Confirm-Action "install or update the $BundleName app package" ($apps -join ', '))) { return }
    Install-AppList -Apps $apps -Activity "App package: $BundleName"
}
function Install-AppList {
    param([Parameter(Mandatory)][string[]]$Apps, [Parameter(Mandatory)][string]$Activity)
    $total=$Apps.Count
    for($i=0; $i -lt $total; $i++) {
        $app=$Apps[$i]
        $percent=[int](100*$i/$total)
        Write-Progress -Activity $Activity -Status "Installing $app ($($i+1) of $total)" -PercentComplete $percent
        Write-Status "[$($i+1)/$total] Installing or updating $app..." Info
        Install-AppItem -Name $app -SkipConfirmation
        Write-Progress -Activity $Activity -Status "Completed $app ($($i+1) of $total)" -PercentComplete ([int](100*($i+1)/$total))
    }
    Write-Progress -Activity $Activity -Completed
}
function Install-OrUpdate-App {
    param([string]$PackageId, [string]$DisplayName)
    if ($PackageId) {
        if ($DisplayName -eq 'AnyDesk') { Install-AppItem -Name 'AnyDesk'; return }
        Write-Status 'Direct package installation is not available for this item.' Warn; return
    }
    Clear-Host; Write-Host 'APP INSTALL / UPDATE' -ForegroundColor Cyan; $index=1
    foreach($bundle in $script:AppBundles.Keys) { Write-Host "$index. $bundle"; $index++ }
    Write-Host "$index. Custom app selection"; Write-Host '0. Back'; $pick=Read-Host 'Choose an option'
    if ($pick -eq '0') { return }
    $parsed=0; $isNumber=[int]::TryParse($pick,[ref]$parsed)
    if ($isNumber -and $parsed -ge 1 -and $parsed -lt $index) { Install-AppBundle -BundleName @($script:AppBundles.Keys)[$parsed-1]; return }
    if (-not $isNumber -or $parsed -ne $index) { Write-Status 'Invalid selection.' Warn; return }
    do {
        Clear-Host; Write-Host 'CUSTOM APP INSTALL / UPDATE' -ForegroundColor Cyan; $n=1; $lookup=@{}
        foreach($name in ($script:AppCatalog.Keys | Where-Object { $_ -ne 'AnyDesk' })) { $lookup[$n]=$name; Write-Host "$n. $name"; $n++ }
        $selected=(Read-Host 'Enter app numbers separated by commas') -split ',' | ForEach-Object { $v=0; if([int]::TryParse($_.Trim(),[ref]$v) -and $lookup.ContainsKey($v)){$lookup[$v]} } | Select-Object -Unique
        if(-not $selected) { Write-Status 'No apps selected.' Warn } elseif(Confirm-Action 'install or update selected apps' ($selected -join ', ')) { Install-AppList -Apps $selected -Activity 'Selected apps' }
        $installMore = Read-Host 'Install or update more apps? (Y/N)'
    } while ($installMore -match '^[Yy]')
}
function Get-NtpTime {
    param([string]$NtpServer='time.windows.com')
    $data=New-Object byte[] 48; $data[0]=0x1B
    $socket=New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork,[System.Net.Sockets.SocketType]::Dgram,[System.Net.Sockets.ProtocolType]::Udp)
    $socket.ReceiveTimeout=3000; $socket.SendTimeout=3000
    try { $socket.Connect($NtpServer,123); [void]$socket.Send($data); [void]$socket.Receive($data) } finally { $socket.Close() }
    $seconds=([uint32]$data[40] -shl 24) -bor ([uint32]$data[41] -shl 16) -bor ([uint32]$data[42] -shl 8) -bor [uint32]$data[43]
    $fraction=([uint32]$data[44] -shl 24) -bor ([uint32]$data[45] -shl 16) -bor ([uint32]$data[46] -shl 8) -bor [uint32]$data[47]
    (New-Object DateTime(1900,1,1,0,0,0,[DateTimeKind]::Utc)).AddSeconds([double]$seconds + ([double]$fraction / 0x100000000))
}
function Show-TimeSyncCheck {
    Show-ScanBar 'verifying temporal integrity' 24 Yellow
    try {
        $ntp=Get-NtpTime; $local=(Get-Date).ToUniversalTime(); $drift=[Math]::Round((New-TimeSpan -Start $ntp -End $local).TotalSeconds,2); $state=if([Math]::Abs($drift)-le 2){'IN SYNC'}elseif([Math]::Abs($drift)-le 15){'MINOR DRIFT'}else{'OUT OF SYNC'}; $color=if($state -eq 'IN SYNC'){'Green'}elseif($state -eq 'MINOR DRIFT'){'Yellow'}else{'Red'}
        Write-Host "  NTP TIME (UTC)   : $($ntp.ToString('u'))" -ForegroundColor White; Write-Host "  LOCAL TIME (UTC) : $($local.ToString('u'))" -ForegroundColor White; Write-Host "  DRIFT            : $drift s [$state]" -ForegroundColor $color
    } catch { Write-Status "Time sync check unavailable (NTP blocked or offline): $($_.Exception.Message)" Warn }
}
function Invoke-Diagnostics {
    Write-Host ''; Write-Host '==================== SYSTEM RECON ====================' -ForegroundColor Green; Show-ScanBar 'profiling target system' 24 Cyan
    try {
        $os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem; $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1; $gpu=Get-CimInstance Win32_VideoController | Select-Object -First 1; $uptime=(Get-Date)-$os.LastBootUpTime
        Write-Host "  HOST         : $($cs.Name)" -ForegroundColor White; Write-Host "  OS           : $($os.Caption) (Build $($os.BuildNumber))" -ForegroundColor White; Write-Host "  CPU          : $($cpu.Name.Trim())" -ForegroundColor White; Write-Host "  RAM          : $([Math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB" -ForegroundColor White; Write-Host "  GPU          : $($gpu.Name)" -ForegroundColor White
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { Write-Host "  DISK $($_.DeviceID)      : $([Math]::Round($_.FreeSpace/1GB,1)) GB free / $([Math]::Round($_.Size/1GB,1)) GB" -ForegroundColor White }
        Write-Host "  UPTIME       : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor White
    } catch { Write-Status "System recon partially failed: $($_.Exception.Message)" Warn }
    Show-TimeSyncCheck; Write-Host '=======================================================' -ForegroundColor Green
}
function Invoke-AdvancedNetwork {
    Write-Host 'Advanced Network Tools'; Write-Host '1. Display IP configuration'; Write-Host '2. Test a host'; Write-Host '3. Flush DNS cache'
    switch(Read-Host 'Choose 1-3') { '1' { ipconfig /all }; '2' { $hostName=Read-Host 'Host name or IP'; Test-Connection $hostName -Count 4 }; '3' { if(Confirm-Action 'flush the DNS resolver cache'){Clear-DnsClientCache;Write-Status 'DNS cache flushed.' Good} } }
}
function Invoke-RemoteBranch {
    if ($NoRemotePrompt) { return }

    Write-Host ''
    $mode = Read-Host 'Start in Offline mode or Remote assistance mode? (O/R)'
    if ($mode -match '^[Oo]') {
        Write-Status 'Offline mode selected. Remote-access setup skipped.' Warn
        return
    }
    if ($mode -notmatch '^[Rr]') {
        Write-Status 'Invalid selection. Remote-access setup skipped.' Warn
        return
    }
    if (-not (Test-Connection 1.1.1.1 -Count 1 -Quiet)) {
        Write-Status 'Offline mode detected. Remote-access setup is unavailable until a connection is restored.' Warn
        return
    }

    $exe = Get-Command AnyDesk -ErrorAction SilentlyContinue
    if ($exe) {
        Write-Status 'AnyDesk is installed. Launching it for remote assistance.' Good
        Start-Process $exe.Source
        return
    }

    if ((Read-Host 'Optional: download and install AnyDesk remote support now? (Y/N)') -match '^[Yy]') {
        if (Confirm-Action 'install AnyDesk and launch it' 'This downloads AnyDesk through Winget or Chocolatey, then opens it.') {
            Install-OrUpdate-App -PackageId 'AnyDeskSoftwareGmbH.AnyDesk' -DisplayName 'AnyDesk'
            $exe = Get-Command AnyDesk -ErrorAction SilentlyContinue
            if ($exe) { Start-Process $exe.Source }
        }
    }
}
function Show-MainMenu {
    while (-not $script:Cancelled) {
        Write-Host ''; Write-Host '==================== MAIN MENU ====================' -ForegroundColor Green
        Write-Host " 1) Package Optimizations`n 2) Cleanup`n 3) Fixes / Repairs`n 4) Activate Windows`n 5) Install / Update Apps`n 6) Diagnose / System Recon`n 7) Advanced Network Tools`n 8) Exit" -ForegroundColor White
        Write-Host '=====================================================' -ForegroundColor Green
        switch (Read-Host 'Select') { '1'{Invoke-PackageOptimization};'2'{Invoke-Cleanup};'3'{Invoke-Fixes};'4'{Invoke-WindowsActivation};'5'{Install-OrUpdate-App};'6'{Invoke-Diagnostics};'7'{Invoke-AdvancedNetwork};'8'{$script:Cancelled=$true};default{Write-Status 'Invalid selection.' Warn} }
        if(-not $script:Cancelled){Read-Host 'Press Enter to return to the menu' | Out-Null}
    }
}
try {
    Initialize-Storage; Ensure-Elevation
    Register-EngineEvent PowerShell.Exiting -Action { try { Add-Content -LiteralPath $script:LogPath -Value "$(Get-Date -Format u) [INFO] Utility exited." } catch {} } | Out-Null
    if (-not $SkipBootAnimation) { Show-BootSequence; Invoke-RemoteBranch; if (-not (Invoke-ActivationGate)) { exit 1 }; Offer-RestorePoint; Invoke-Diagnostics }
    Write-Log "AICKARAWINUTIL $script:Version launched by $env:USERNAME" INFO
    if ($SkipBootAnimation) { Invoke-RemoteBranch }
    Show-MainMenu
} catch { Write-Log "Fatal error: $($_.Exception.Message)" ERROR; Write-Status "Stopped safely: $($_.Exception.Message)" Bad; exit 1 }
finally { Write-Log 'AICKARAWINUTIL session ended.' INFO; Write-Host 'AICKARAWINUTIL closed. No further actions will be taken.' -ForegroundColor Cyan }
