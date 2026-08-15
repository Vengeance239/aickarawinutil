# Robust Import-Configuration that tolerates missing fields in apps.json
function Import-Configuration {
    <#
    Robust loader for config/access-code.json and config/apps.json that tolerates
    missing optional fields (Category, DownloadOnly, Recommended) and skips
    invalid app entries rather than failing hard.
    #>
    try {
        if ($script:IsRemoteRun) {
            # Running via "irm <url> | iex" - there's no file on disk, so pull the config
            # JSON straight from GitHub instead of trying to read a local config folder.
            $accessConfig = Invoke-RestMethod -Uri $script:RemoteAccessCodeUrl -UseBasicParsing
            $appsConfig   = Invoke-RestMethod -Uri $script:RemoteAppsConfigUrl -UseBasicParsing
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
            # Each $app should be an object with Name and Winget. If not, skip but log.
            if (-not ($app -is [PSObject])) { Write-Log "Skipping invalid app entry (not an object): $app" WARN; continue }

            $name = if ($app.PSObject.Properties.Match('Name')) { [string]$app.Name } else { $null }
            $winget = if ($app.PSObject.Properties.Match('Winget')) { [string]$app.Winget } else { $null }
            $choco = if ($app.PSObject.Properties.Match('Choco')) { [string]$app.Choco } else { 'na' }

            if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($winget)) {
                throw "Each app must include a Name and Winget package ID. Invalid entry: $($app | ConvertTo-Json -Depth 3)"
            }

            $category = if ($app.PSObject.Properties.Match('Category')) { [string]$app.Category } else { 'Uncategorized' }
            $downloadOnly = if ($app.PSObject.Properties.Match('DownloadOnly')) { [bool]$app.DownloadOnly } else { $false }
            $recommended = if ($app.PSObject.Properties.Match('Recommended')) { [bool]$app.Recommended } else { $false }

            $script:AppCatalog[$name] = @{ Winget=$winget; Choco=$choco; Category=$category; DownloadOnly=$downloadOnly; Recommended=$recommended }
        }

        $script:AppBundles = [ordered]@{}
        $previousApps = @()
        foreach ($bundle in @($appsConfig.Bundles)) {
            if (-not ($bundle -is [PSObject])) { Write-Log "Skipping invalid bundle entry: $bundle" WARN; continue }
            if (-not ($bundle.PSObject.Properties.Match('Name'))) { throw 'Each app bundle must include a Name.' }
            $bundleName = [string]$bundle.Name
            $bundleApps = @($bundle.Apps | ForEach-Object { [string]$_ })
            foreach ($appName in $bundleApps) { if (-not $script:AppCatalog.Contains($appName)) { throw "Bundle '$($bundleName)' contains unknown app '$appName'." } }
            $script:AppBundles[$bundleName] = if ($bundle.Cumulative -eq $true) { @($previousApps + $bundleApps) } else { $bundleApps }
            $previousApps = $script:AppBundles[$bundleName]
        }

        Write-Log 'Configuration loaded.' INFO
    } catch {
        Write-Log "Import-Configuration failed: $($_.Exception.Message)" ERROR
        throw
    }
}
