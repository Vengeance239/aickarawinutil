# Extended cleanup functions (safe-by-default)
[CmdletBinding()]
param()

function Clear-TempFilesExtended {
    <#
    .SYNOPSIS
    Extended temporary file cleanup including Windows temp, user temp, and optional browser caches.
    Supports -WhatIf/-Confirm via ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$IncludeBrowserCaches,
        [switch]$IncludeWindowsUpdateCache
    )

    $targets = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp") | Where-Object { $_ -and (Test-Path $_) }
    Write-Host ("Found {0} target folders to scan." -f $targets.Count) -ForegroundColor Yellow

    $candidates = foreach ($t in $targets) { Get-ChildItem -LiteralPath $t -Force -File -Recurse -ErrorAction SilentlyContinue }
    $count = @($candidates).Count; $sizeMB = (@($candidates | Measure-Object -Property Length -Sum).Sum / 1MB)
    Write-Host ("Candidate files: {0:N0} ({1:N1} MB)" -f $count, $sizeMB) -ForegroundColor Yellow
    if ($count -eq 0) { Write-Status 'No temporary files found.' Info; return }

    if (-not (Confirm-Action 'clean temporary files' ($targets -join [Environment]::NewLine))) { return }

    Invoke-Safely 'Extended temp cleanup' {
        $processed = 0; $removed=0; $removedBytes=0
        foreach ($f in $candidates) {
            $processed++; if ($PSCmdlet.ShouldProcess($f.FullName,'Remove')) {
                try { $len=$f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $removed++; $removedBytes += $len } catch { Write-Log "Skipping locked file: $($f.FullName)" INFO }
            }
            Write-Progress -Activity 'Clearing temp' -Status $f.Name -PercentComplete ([int](100*$processed/$count))
        }
        Write-Progress -Activity 'Clearing temp' -Completed
        Write-Status ("Removed {0:N0} files ({1:N1} MB)." -f $removed,($removedBytes/1MB)) Good

        if ($IncludeWindowsUpdateCache) {
            if (Confirm-Action 'Clear Windows Update download cache' 'This removes files in C:\Windows\SoftwareDistribution\Download') {
                try { Stop-Service wuauserv -ErrorAction SilentlyContinue; Remove-Item -LiteralPath "$env:Windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue; Start-Service wuauserv -ErrorAction SilentlyContinue }
                catch { Write-Log "Windows Update cache clear failed: $($_.Exception.Message)" ERROR }
            }
        }

        if ($IncludeBrowserCaches) {
            Write-Status 'Removing common browser cache folders (Chrome/Edge/Firefox) where found.' Info
            $browsers = @(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
            )
            foreach ($p in $browsers) {
                if (Test-Path $p) {
                    if ($PSCmdlet.ShouldProcess($p,'Remove')) { try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } catch { Write-Log "Browser cache removal failed: $($_.Exception.Message)" ERROR } }
                }
            }
        }
    } | Out-Null
}

function Recycle-Bin-Empty {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($PSCmdlet.ShouldProcess('Recycle Bin', 'Empty')) {
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Status 'Recycle Bin emptied.' Good
        }
        catch {
            Write-Log "Empty recycle bin failed: $($_.Exception.Message)" ERROR
            Write-Status 'Could not empty Recycle Bin.' Bad
        }
    }
}
