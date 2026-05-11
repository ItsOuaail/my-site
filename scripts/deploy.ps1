# ============================================================
# deploy.ps1
# Deploys StopwatchApp to IIS on SIRIUS1
# Called by GitHub Actions via WinRM
# ============================================================

param(
    [string]$SiteName   = "ouaail-stopwatch",
    [string]$DeployPath = "C:\inetpub\wwwroot\ouaail-stopwatch",
    [string]$SourcePath = "C:\deployments\incoming",
    [string]$BackupRoot = "C:\deployments\backups"
)

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$BackupRoot\$SiteName`_$timestamp"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " StopwatchApp Deployment Script"           -ForegroundColor Cyan
Write-Host " Site    : $SiteName"                      -ForegroundColor Cyan
Write-Host " Target  : $DeployPath"                    -ForegroundColor Cyan
Write-Host " Backup  : $backupPath"                    -ForegroundColor Cyan
Write-Host " Time    : $timestamp"                     -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Import-Module WebAdministration

# ── STEP 1: Stop site & app pool ──────────────────────────
Write-Host "`n[1/6] Stopping IIS site and app pool..." -ForegroundColor Yellow
try {
    Stop-WebSite -Name $SiteName -ErrorAction Stop
    Write-Host "      Site stopped." -ForegroundColor Green
} catch {
    Write-Warning "      Could not stop site (may already be stopped): $_"
}

try {
    Stop-WebAppPool -Name $SiteName -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "      App pool stopped." -ForegroundColor Green
} catch {
    Write-Warning "      Could not stop app pool: $_"
}

# ── STEP 2: Backup current deployment ─────────────────────
Write-Host "`n[2/6] Creating backup..." -ForegroundColor Yellow
if (!(Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot | Out-Null
}
if (Test-Path $DeployPath) {
    Copy-Item -Recurse -Force $DeployPath $backupPath
    Write-Host "      Backup saved to: $backupPath" -ForegroundColor Green
} else {
    Write-Host "      No existing deployment found — skipping backup." -ForegroundColor Gray
}

# ── STEP 3: Clean old files ────────────────────────────────
Write-Host "`n[3/6] Removing old files..." -ForegroundColor Yellow
if (Test-Path $DeployPath) {
    Remove-Item -Recurse -Force "$DeployPath\*"
    Write-Host "      Old files removed." -ForegroundColor Green
} else {
    New-Item -ItemType Directory -Path $DeployPath | Out-Null
    Write-Host "      Deploy folder created." -ForegroundColor Green
}

# ── STEP 4: Copy new files ─────────────────────────────────
Write-Host "`n[4/6] Copying new files to $DeployPath ..." -ForegroundColor Yellow
if (!(Test-Path $SourcePath)) {
    Write-Error "Source path not found: $SourcePath"
    exit 1
}
Copy-Item -Recurse -Force "$SourcePath\*" $DeployPath
Write-Host "      New files deployed." -ForegroundColor Green

# ── STEP 5: Start app pool & site ──────────────────────────
Write-Host "`n[5/6] Starting app pool and site..." -ForegroundColor Yellow
Start-WebAppPool -Name $SiteName
Start-Sleep -Seconds 3
Start-WebSite -Name $SiteName
Write-Host "      App pool and site started." -ForegroundColor Green

# ── STEP 6: Verify ─────────────────────────────────────────
Write-Host "`n[6/6] Verifying deployment..." -ForegroundColor Yellow
$siteState    = (Get-WebSite -Name $SiteName).State
$appPoolState = (Get-WebAppPool -Name $SiteName).State

Write-Host "      Site state    : $siteState"
Write-Host "      App pool state: $appPoolState"

if ($siteState -eq "Started" -and $appPoolState -eq "Started") {
    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host " DEPLOYMENT SUCCESSFUL"                       -ForegroundColor Green
    Write-Host " $SiteName is LIVE"                          -ForegroundColor Green
    Write-Host " URL: https://ouaail-stopwatch.ms-strategies.com" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    exit 0
} else {
    Write-Error "DEPLOYMENT FAILED — site or app pool did not start correctly"
    Write-Host "Rolling back to backup: $backupPath" -ForegroundColor Red
    Remove-Item -Recurse -Force "$DeployPath\*"
    Copy-Item -Recurse -Force "$backupPath\*" $DeployPath
    Start-WebAppPool -Name $SiteName
    Start-Sleep -Seconds 2
    Start-WebSite -Name $SiteName
    Write-Host "Rollback complete." -ForegroundColor Yellow
    exit 1
}
