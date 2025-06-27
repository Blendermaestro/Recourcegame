# Flutter Calendar App Runner - PowerShell Version
# This script ensures we always run from the correct directory

Write-Host "Starting Flutter Calendar App..." -ForegroundColor Green
Write-Host ""

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Navigate to the calendar_app directory
$CalendarAppDir = Join-Path $ScriptDir "calendar_app"
Set-Location $CalendarAppDir

# Check if we're in the right directory by looking for pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "ERROR: pubspec.yaml not found!" -ForegroundColor Red
    Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Expected to be in: $CalendarAppDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Make sure this script is placed in the CalendarApp root directory" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found pubspec.yaml - good!" -ForegroundColor Green
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Run flutter doctor first to check setup
Write-Host "Checking Flutter setup..." -ForegroundColor Yellow
try {
    flutter doctor --version
    Write-Host ""
} catch {
    Write-Host "Warning: Flutter doctor check failed" -ForegroundColor Yellow
    Write-Host ""
}

# Run the app
Write-Host "Starting Flutter app in Chrome..." -ForegroundColor Green
try {
    flutter run -d chrome
} catch {
    Write-Host ""
    Write-Host "ERROR: Flutter run failed!" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
} 