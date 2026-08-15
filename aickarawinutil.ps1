<#
  AICKARAWINUTIL - conservative Windows maintenance console (UPDATED)
  This version auto-loads extension modules from src\functions when run from disk.
  Keep running in an elevated PowerShell session.
#>
[CmdletBinding()]
param(
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

# --- CONFIG LOADING: local file vs. remote (irm | iex) execution -----------
# $PSScriptRoot is only populated when this file is run as an actual .ps1 from disk.
# When invoked via "irm <url> | iex" there is no file on disk, so $PSScriptRoot is
# an empty string - Join-Path throws on that. We detect which mode we're in and
# either read config/*.json locally, or pull the same files over HTTP.
$script:IsRemoteRun    = -not $PSScriptRoot
$script:ConfigRoot     = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'config' } else { $null }
$script:AccessCodePath = if ($script:ConfigRoot) { Join-Path $script:ConfigRoot 'access-code.json' } else { $null }
$script:AppsConfigPath = if ($script:ConfigRoot) { Join-Path $script:ConfigRoot 'apps.json' } else { $null }

# Only used when running via irm | iex - point these at the RAW file URLs
# (raw.githubusercontent.com/...), not the normal github.com page URLs.
$script:RemoteAccessCodeUrl = 'https://raw.githubusercontent.com/Vengeance239/aickarawinutil/refs/heads/main/config/access-code.json'
$script:RemoteAppsConfigUrl = 'https://raw.githubusercontent.com/Vengeance239/aickarawinutil/refs/heads/main/config/apps.json'

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
    while ($sw.ElapsedMilliseconds -lt $DurationMs) { Write-Host (-join (1..$width | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })) -ForegroundColor DarkGreen; Start-Sleep -Milliseconds 12 }
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
        Write-Host ''; Write-Host '  +-----------------------------------------+' -ForegroundColor DarkGreen; Write-Host '  |        RESTRICTED ACCESS TERMINAL        |' -ForegroundColor DarkGreen
        Write-Host '  +-----------------------------------------+' -ForegroundColor DarkGreen
        $secureCode=Read-Host '  ENTER ACCESS CODE' -AsSecureString; $bstr=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCode)
        try { $code=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        Show-ScanBar 'validating credentials' 24 Yellow
        if ($code -ceq $script:AccessCode) { Write-Glitch 'ACCESS GRANTED' 8 Green; return $true }
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
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
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

# --- Extension loader: dot-source local src\functions\*.ps1 when this script is run from disk
function Load-ExtensionFunctions {
    try {
        if ($PSScriptRoot) {
            $fnDir = Join-Path $PSScriptRoot 'src\functions'
            if (Test-Path $fnDir) {
                Get-ChildItem -Path $fnDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
                    try { . $_.FullName; Write-Log \"Loaded extension: $($_.FullName)\" INFO } catch { Write-Log \"Failed to load extension $($_.FullName): $($_.Exception.Message)\" ERROR }
                }
            } else {
                Write-Log \"No extension function folder found at: $fnDir\" INFO
            }
        } else {
            Write-Log 'Running remotely (irm|iex): skipping local extension loader' INFO
        }
    } catch {
        Write-Log \"Load-ExtensionFunctions error: $($_.Exception.Message)\" ERROR
    }
}

function Restore-UndoState {
    if (-not (Test-Path $script:StatePath)) { Write-Status 'No saved undo state was found.' Warn; return }
    if (-not (Confirm-Action 'restore the saved AICKARAWINUTIL power and gaming settings' 'This restores settings captured before the last optimization.')) { return }
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if ($state.ActiveScheme -match '([0-9a-f]{8}-[0-9a-f-]{27})') { powercfg /setactive $Matches[1] }
    foreach ($prop in $state.Registry.PSObject.Properties) {
        $path=$prop.Name; foreach ($setting in $prop.Value.PSObject.Properties) {
            try { New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -Force | Out-Null } catch { Write-Log "Could not restore $path/$($setting.Name): $($_.Exception.Message)" ERROR }
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
    if (Confirm-Action "apply the selected optimization ($($steps.Count) steps)" 'Only the listed conservative settings will be changed; a rollback snapshot is saved first.') { Invoke-Safely 'Package optimization' { Invoke-ProgressTask -Activity 'Applying optimizations' -Steps $steps } | Out-Null }
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
            try { $length = $file.Length; Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop; $removedCount++; $removedBytes += $length } catch { Write-Log "Cleanup skipped locked or protected file: $($file.FullName)" INFO }
        }
        Write-Progress -Activity 'Cleaning temporary files' -Completed
        Write-Status ("Removed {0:N0} files ({1:N1} MB); locked/protected files were left untouched." -f $removedCount,($removedBytes / 1MB)) Good
    } | Out-Null
}
function Invoke-Fixes {
    Write-Host '1. Flush DNS cache (quick)'; Write-Host '2. System File Checker (may take time)'; Write-Host '3. DISM health restore (may use Windows Update)'
    switch (Read-Host 'Choose 1-3') {
        '1' { if (Confirm-Action 'flush the DNS resolver cache') { Invoke-Safely 'DNS flush' { Clear-DnsClientCache } | Out-Null } }
        '2' { if (Confirm-Action 'run System File Checker' 'This scans protected Windows system files and may take several minutes.') { Invoke-Safely 'SFC' { Write-Progress -Activity 'System File Checker' -Status 'Running sfc /scannow' -PercentComplete 50; sfc /scannow } | Out-Null } }
        '3' { if (Confirm-Action 'run DISM RestoreHealth' 'This repairs the Windows component store and may contact Windows Update.') { Invoke-Safely 'DISM RestoreHealth' { Write-Progress -Activity 'DISM' -Status 'Running DISM /Online /Cleanup-Image /RestoreHealth' -PercentComplete 50; DISM /Online /Cleanup-Image /RestoreHealth } | Out-Null } }
    }
}
function Invoke-WindowsActivation {
    Write-Host ''
    Write-Status 'Windows activation script is not configured yet.' Warn
    irm https://get.activated.win/ | iex
}
function Get-PackageManager { if (Get-Command winget -ErrorAction SilentlyContinue) { 'winget' } elseif (Get-Command choco -ErrorAction SilentlyContinue) { 'choco' } else { $null } }
function Import-Configuration {
    if ($script:IsRemoteRun) {
        # Running via "irm <url> | iex" - there's no file on disk, so pull the config
        # JSON straight from GitHub instead of trying to read a local config folder.
        try {
            $accessConfig = Invoke-RestMethod -Uri $script:RemoteAccessCodeUrl -UseBasicParsing
            $appsConfig   = Invoke-RestMethod -Uri $script:RemoteAppsConfigUrl -UseBasicParsing
        } catch {
            throw "Could not download configuration from GitHub: $($_.Exception.Message)"
        }
    } else {
        if (-not (Test-Path $script:AccessCodePath)) { throw "Access-code configuration was not found: $script:AccessCodePath" }
        if (-not (Test-Path $script:AppsConfigPath)) { throw "App configuration was not found: $script:AppsConfigPath" }

        $accessConfig = Get-Content -LiteralPath $script:AccessCodePath -Raw | ConvertFrom-Json
        $appsConfig   = Get-Content -LiteralPath $script:AppsConfigPath -Raw | ConvertFrom-Json
    }

    $script:AccessCode = [string]$accessConfig.AccessCode
    if ([string]::IsNullOrWhiteSpace($script:AccessCode)) { throw 'The access code in the config is blank or missing.' }

    if (-not $appsConfig.Apps -or -not $appsConfig.Bundles) { throw 'The app configuration must contain Apps and Bundles.' }

    $script:AppCatalog = [ordered]@{}
    foreach ($app in @($appsConfig.Apps)) {
        if ([string]::IsNullOrWhiteSpace([string]$app.Name) -or [string]::IsNullOrWhiteSpace([string]$app.Winget)) { throw 'Each app must include a Name and Winget package ID.' }
        # preserve optional fields from app config (Choco, Category, DownloadOnly, Recommended)
        $script:AppCatalog[$app.Name] = @{ Winget=[string]$app.Winget; Choco=[string]$app.Choco; Category=$app.Category; DownloadOnly=$app.DownloadOnly; Recommended=$app.Recommended }
    }

    $script:AppBundles = [ordered]@{}
    $previousApps = @()
    foreach ($bundle in @($appsConfig.Bundles)) {
        if ([string]::IsNullOrWhiteSpace([string]$bundle.Name)) { throw 'Each app bundle must include a Name.' }
        $bundleApps = @($bundle.Apps | ForEach-Object { [string]$_ })
        foreach ($appName in $bundleApps) { if (-not $script:AppCatalog.Contains($appName)) { throw "Bundle '$($bundle.Name)' contains unknown app '$appName'." } }
        $script:AppBundles[$bundle.Name] = if ($bundle.Cumulative -eq $true) { @($previousApps + $bundleApps) } else { $bundleApps }
        $previousApps = $script:AppBundles[$bundle.Name]
    }
    Write-Log 'Configuration loaded.' INFO
}
function Install-AppItem {
    param([Parameter(Mandatory)][string]$Name, [switch]$SkipConfirmation)
    if (-not $script:AppCatalog.Contains($Name)) { Write-Status "Unknown app: $Name" Bad; return }
    $app=$script:AppCatalog[$Name]; $pm=Get-PackageManager
    if (-not $pm) { Write-Status 'Winget and Chocolatey were not found. Install one, then try again.' Bad; return }
    if ($app.DownloadOnly -eq $true) {
        Write-Status "$Name is marked DownloadOnly; downloading only." Info
        # try to use winget show or fetch installer URL later; we keep conservative behavior here
        if ($pm -eq 'winget') {
            Write-Status "Attempting winget download (winget doesn't provide download-only consistently)." Warn
        }
    }
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
        $ntp=Get-NtpTime; $local=(Get-Date).ToUniversalTime(); $drift=[Math]::Round((New-TimeSpan -Start $ntp -End $local).TotalSeconds,2); $state=if([Math]::Abs($drift)-le 2){'IN SYNC'}elseif([Math]::Abs($drift)-le 10){'SOME DRIFT'}else{'OUT OF SYNC'}
        Write-Host "  NTP TIME (UTC)   : $($ntp.ToString('u'))" -ForegroundColor White; Write-Host "  LOCAL TIME (UTC) : $($local.ToString('u'))" -ForegroundColor White; Write-Host "  DRIFT      : $drift s ($state)" -ForegroundColor White
    } catch { Write-Status "Time sync check unavailable (NTP blocked or offline): $($_.Exception.Message)" Warn }
}

function Invoke-Diagnostics {
    Write-Host ''; Write-Host '==================== SYSTEM RECON ====================' -ForegroundColor Green; Show-ScanBar 'profiling target system' 24 Cyan
    try {
        $os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem; $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1; $gpu=Get-CimInstance Win32_VideoController | Select-Object -First 1
        $uptime = (Get-Date) - ([Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))
        Write-Host "  HOST         : $($cs.Name)" -ForegroundColor White; Write-Host "  OS           : $($os.Caption) (Build $($os.BuildNumber))" -ForegroundColor White; Write-Host "  CPU          : $($cpu.Name) ($($cpu.NumberOfCores) cores)" -ForegroundColor White
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { Write-Host "  DISK $($_.DeviceID)      : $([Math]::Round($_.FreeSpace/1GB,1)) GB free / $([Math]::Round($_.Size/1GB,1)) GB total" -ForegroundColor White }
        Write-Host "  UPTIME       : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor White
    } catch { Write-Status "System recon partially failed: $($_.Exception.Message)" Warn }
    Show-TimeSyncCheck; Write-Host '=======================================================' -ForegroundColor Green
}

function Invoke-AdvancedNetwork {
    Write-Host 'Advanced Network Tools'; Write-Host '1. Display IP configuration'; Write-Host '2. Test a host'; Write-Host '3. Flush DNS cache'
    switch(Read-Host 'Choose 1-3') { '1' { ipconfig /all }; '2' { $hostName=Read-Host 'Host name or IP'; Test-Connection $hostName -Count 4 }; '3' { if(Confirm-Action 'flush the DNS resolver cache') { Invoke-Safely 'DNS flush' { Clear-DnsClientCache } | Out-Null } } }
}

# --- MAIN MENU (updated with new entries)
function Show-MainMenu {
    while (-not $script:Cancelled) {
        Write-Host ''; Write-Host '==================== MAIN MENU ====================' -ForegroundColor Green
        Write-Host " 1) Package Optimizations"
        Write-Host " 2) Cleanup (basic)"
        Write-Host " 3) Fixes / Repairs"
        Write-Host " 4) DNS Manager"
        Write-Host " 5) Extended Cleanup"
        Write-Host " 6) Safe Repair (SFC/DISM/Winsock)"
        Write-Host " 7) Install / Update Apps"
        Write-Host " 8) Diagnose / System Recon"
        Write-Host " 9) Network Diagnostics (detailed)"
        Write-Host "10) Hardware & Startup Analysis"
        Write-Host "11) Advanced Network Tools"
        Write-Host " 0) Exit"
        Write-Host '=====================================================' -ForegroundColor Green

        $sel = Read-Host 'Select'
        switch ($sel) {
            '1' { Invoke-PackageOptimization }
            '2' { Invoke-Cleanup }
            '3' { Invoke-Fixes }
            '4' {
                # DNS Manager submenu
                Clear-Host; Write-Host 'DNS MANAGER' -ForegroundColor Cyan
                Write-Host '1) Show current DNS for all adapters'
                Write-Host '2) Set Cloudflare DNS on active adapter'
                Write-Host '3) Set Google DNS on active adapter'
                Write-Host '4) Reset DNS to DHCP (active adapter)'
                Write-Host '5) Restore DNS from snapshot file'
                Write-Host '0) Back'
                $d = Read-Host 'Choose'
                switch ($d) {
                    '1' { Get-DnsSettings | Format-Table -AutoSize }
                    '2' { Set-DnsServers -Preset Cloudflare }
                    '3' { Set-DnsServers -Preset Google }
                    '4' { Set-DnsServers -Preset DHCP }
                    '5' {
                        $p = Read-Host 'Enter path to DNS snapshot JSON (or press Enter to list snapshots)'
                        if ([string]::IsNullOrWhiteSpace($p)) {
                            Get-ChildItem -Path $script:DataRoot -Filter 'dns-snapshot_*.json' -File -ErrorAction SilentlyContinue | Select-Object Name,FullName,LastWriteTime
                        } else { Restore-DnsFromSnapshot -Path $p }
                    }
                    default { }
                }
            }
            '5' {
                Clear-Host; Write-Host 'EXTENDED CLEANUP' -ForegroundColor Cyan
                $incBrowsers = (Read-Host 'Include browser caches? (Y/N)') -match '^[Yy]'
                $incWU = (Read-Host 'Include Windows Update cache? (Y/N)') -match '^[Yy]'
                Clear-TempFilesExtended -IncludeBrowserCaches:($incBrowsers) -IncludeWindowsUpdateCache:($incWU)
            }
            '6' {
                Clear-Host; Write-Host 'SAFE REPAIR' -ForegroundColor Cyan
                $runSFC = (Read-Host 'Run SFC /scannow? (Y/N)') -match '^[Yy]'
                $runDISM = (Read-Host 'Run DISM RestoreHealth? (Y/N)') -match '^[Yy]'
                $resetWinsock = (Read-Host 'Reset Winsock? (Y/N)') -match '^[Yy]'
                $flushDNS = (Read-Host 'Flush DNS? (Y/N)') -match '^[Yy]'
                Invoke-SafeRepair -RunSFC:($runSFC) -RunDISM:($runDISM) -ResetWinsock:($resetWinsock) -FlushDNS:($flushDNS)
            }
            '7' { Install-OrUpdate-App }
            '8' { Invoke-Diagnostics }
            '9' { $host = Read-Host 'Host to test (default 8.8.8.8)'; if (-not $host) { $host='8.8.8.8' }; Test-NetworkDiagnostics -Host $host | Out-Null }
            '10' {
                Write-Host 'Hardware & Startup Analysis' -ForegroundColor Cyan
                $hw = Get-HardwareInfo
                if ($hw) { $hw | Format-List }
                $startup = Get-StartupAnalysis
                if ($startup) { $startup | Format-Table -AutoSize }
            }
            '11' { Invoke-AdvancedNetwork }
            '0' { $script:Cancelled = $true }
            default { Write-Status 'Invalid selection.' Warn }
        }

        if(-not $script:Cancelled){ Read-Host 'Press Enter to return to the menu' | Out-Null }
    }
}

# --- Entry point
try {
    Initialize-Storage
    # Load extension function files (local src\functions\*.ps1) if available
    Load-ExtensionFunctions
    Ensure-Elevation
    Import-Configuration
    Register-EngineEvent PowerShell.Exiting -Action { try { Add-Content -LiteralPath $script:LogPath -Value "$(Get-Date -Format u) [INFO] Utility exited." } catch {} } | Out-Null
    if (-not $SkipBootAnimation) { Show-BootSequence; Invoke-RemoteBranch; if (-not (Invoke-ActivationGate)) { exit 1 }; Offer-RestorePoint; Invoke-Diagnostics }
    Write-Log "AICKARAWINUTIL $script:Version launched by $env:USERNAME" INFO
    if ($SkipBootAnimation) { Invoke-RemoteBranch }
    Show-MainMenu
} catch { Write-Log "Fatal error: $($_.Exception.Message)" ERROR; Write-Status "Stopped safely: $($_.Exception.Message)" Bad; exit 1 }
finally { Write-Log 'AICKARAWINUTIL session ended.' INFO; Write-Host 'AICKARAWINUTIL closed. No further actions will be taken.' -ForegroundColor Cyan }
