# Additional diagnostics helpers
function Get-HardwareInfo {
    <#
    .SYNOPSIS
    Collect basic hardware information (CPU, Memory, Disks, GPU).
    .OUTPUTS PSCustomObject
    #>
    try {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1 -ErrorAction SilentlyContinue
        $disks=Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
        $logical = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Manufacturer = $cs.Manufacturer
            Model = $cs.Model
            CPU = $cpu.Name
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            TotalPhysicalMemoryGB = [math]::Round($cs.TotalPhysicalMemory/1GB,2)
            Disks = $logical | Select-Object DeviceID, @{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}}, @{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}}
            GPU = $gpu.Name
            OS = $os.Caption
        }
    } catch {
        Write-Log "Get-HardwareInfo failed: $($_.Exception.Message)" ERROR
        return $null
    }
}

function Get-StartupAnalysis {
    <#
    .SYNOPSIS
    Enumerate common startup locations and return a list with basic risk flags.
    #>
    $results = @()
    # Registry Run keys
    $runKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')
    foreach ($k in $runKeys) {
        try {
            $items = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
            if ($items) {
                foreach ($p in $items.PSObject.Properties) {
                    if ($p.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') { continue }
                    $exe = $p.Value -as [string]
                    $flag = if ($exe -match '\.exe') { 'LikelyExe' } else { 'Unknown' }
                    $results += [PSCustomObject]@{ Source='Registry'; Location=$k; Name=$p.Name; Command=$exe; Flag=$flag }
                }
            }
        } catch { }
    }
    # Startup folder
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    if (Test-Path $startup) { Get-ChildItem -Path $startup -File -ErrorAction SilentlyContinue | ForEach-Object { $results += [PSCustomObject]@{ Source='StartupFolder'; Location=$startup; Name=$_.Name; Command=$_.FullName; Flag='File' } } }

    return $results
}
