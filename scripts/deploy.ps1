param(
    [string]$SiteName = "MyApp",
    [string]$DeployPath = "C:\inetpub\wwwroot\MyApp",
    [string]$SourcePath = "C:\deployments\latest"
)

Write-Host "Starting deployment of $SiteName..."

# Stop IIS site
try {
    Stop-WebSite -Name $SiteName
    Write-Host "Site stopped."
} catch {
    Write-Warning "Could not stop site: $_"
}

# Stop app pool
try {
    Stop-WebAppPool -Name $SiteName
    Write-Host "App pool stopped."
} catch {
    Write-Warning "Could not stop app pool: $_"
}

# Backup current version
$backupPath = "C:\deployments\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (Test-Path $DeployPath) {
    Copy-Item -Recurse $DeployPath $backupPath
    Write-Host "Backup created at $backupPath"
}

# Deploy new files
Remove-Item -Recurse -Force "$DeployPath\*"
Copy-Item -Recurse "$SourcePath\*" $DeployPath
Write-Host "Files deployed."

# Start app pool and site
Start-WebAppPool -Name $SiteName
Start-WebSite -Name $SiteName

Write-Host "Deployment complete. $SiteName is live."
