# School Management System - Quick Run Script (Windows PowerShell)
# This script sets up and runs the project with one command

$ErrorActionPreference = "Stop"

Write-Host "🚀 School Management System - Quick Start" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

# Check if Flutter is installed
try {
    flutter --version | Out-Null
} catch {
    Write-Host "❌ Flutter is not installed!" -ForegroundColor Red
    Write-Host "Please install Flutter from: https://flutter.dev/docs/get-started/install" -ForegroundColor White
    exit 1
}

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Check for devices
Write-Host ""
Write-Host "📱 Available devices:" -ForegroundColor Yellow
flutter devices

# Run the app
Write-Host ""
Write-Host "🎯 Starting app..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
flutter run

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
