# ============================================================
# deploy.ps1 — runs on SIRIUS1
# Copies files from C:\deployments\incoming to the IIS site
# ============================================================

$ErrorActionPreference = 'Stop'

$siteName   = 'ouaail-stopwatch'
$deployPath = 'C:\inetpub\wwwroot\ouaail-stopwatch'
$sourcePath = 'C:\deployments\incoming'
$backupRoot = 'C:\deployments\backups'
$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupRoot ($siteName + '_' + $timestamp)

Write-Host '=========================================='
Write-Host (' Deploying: ' + $siteName)
Write-Host (' Timestamp: ' + $timestamp)
Write-Host '=========================================='

Import-Module WebAdministration

Write-Host '[1/6] Stopping site and app pool...'
Stop-WebSite    -Name $siteName -ErrorAction SilentlyContinue
Stop-WebAppPool -Name $siteName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host '[2/6] Backing up current version...'
if (Test-Path $deployPath) {
    Copy-Item -Recurse -Force $deployPath $backupPath
    Write-Host ('      Backup saved: ' + $backupPath)
} else {
    Write-Host '      No existing files, skipping backup.'
}

Write-Host '[3/6] Removing old files...'
if (Test-Path $deployPath) {
    Get-ChildItem -Path $deployPath -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $deployPath | Out-Null
}

Write-Host '[4/6] Copying new files from incoming...'
$items = Get-ChildItem -Path $sourcePath -Force
Write-Host ('      Found ' + $items.Count + ' items in source')
foreach ($item in $items) {
    Copy-Item -Path $item.FullName -Destination $deployPath -Recurse -Force
}
$deployedItems = Get-ChildItem -Path $deployPath -Force
Write-Host ('      ' + $deployedItems.Count + ' items now in deploy path')

Write-Host '[5/6] Starting app pool and site...'
Start-WebAppPool -Name $siteName
Start-Sleep -Seconds 3
Start-WebSite    -Name $siteName
Start-Sleep -Seconds 2

Write-Host '[6/6] Verifying...'
Import-Module WebAdministration -Force
Start-Sleep -Seconds 2
$siteState = (Get-Item ("IIS:\Sites\" + $siteName)).State
$poolState = (Get-Item ("IIS:\AppPools\" + $siteName)).State
Write-Host ('      Site: ' + $siteState + ' | Pool: ' + $poolState)

if ($siteState -eq 'Started' -and $poolState -eq 'Started') {
    Write-Host '=========================================='
    Write-Host ' SUCCESS - Site is LIVE'
    Write-Host ' https://ouaail-stopwatch.ms-strategies.com'
    Write-Host '=========================================='
    exit 0
} else {
    Write-Host 'FAILED - rolling back'
    Get-ChildItem -Path $deployPath -Force | Remove-Item -Recurse -Force
    if (Test-Path $backupPath) {
        Copy-Item -Path ($backupPath + '\*') -Destination $deployPath -Recurse -Force
        Start-WebAppPool -Name $siteName
        Start-Sleep -Seconds 2
        Start-WebSite    -Name $siteName
    }
    exit 1
}