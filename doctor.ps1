# School Management System - Pre-Flight Check Script (Windows PowerShell)
# This script checks if your environment is ready to run the project

Write-Host "🏥 Running Environment Health Check..." -ForegroundColor Cyan
Write-Host ""

$Errors = 0
$Warnings = 0

# Check Flutter installation
Write-Host "📱 Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter installed: $flutterVersion" -ForegroundColor Green
    
    # Extract version number
    if ($flutterVersion -match "Flutter (\d+\.\d+\.\d+)") {
        $currentVersion = [version]$matches[1]
        $requiredVersion = [version]"3.24.0"
        
        if ($currentVersion -lt $requiredVersion) {
            Write-Host "⚠️  Warning: Flutter version $currentVersion is older than recommended $requiredVersion" -ForegroundColor Yellow
            $Warnings++
        }
    }
} catch {
    Write-Host "❌ Flutter not found" -ForegroundColor Red
    Write-Host "   Install from: https://flutter.dev/docs/get-started/install" -ForegroundColor White
    $Errors++
}
Write-Host ""

# Check Dart
Write-Host "🎯 Checking Dart..." -ForegroundColor Yellow
try {
    $dartVersion = dart --version 2>&1
    Write-Host "✅ Dart installed: $dartVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Dart not found (usually comes with Flutter)" -ForegroundColor Yellow
    $Warnings++
}
Write-Host ""

# Check Git
Write-Host "📦 Checking Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version 2>&1
    Write-Host "✅ Git installed: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git not found" -ForegroundColor Red
    Write-Host "   Install from: https://git-scm.com/" -ForegroundColor White
    $Errors++
}
Write-Host ""

# Check project dependencies
Write-Host "📚 Checking Project Dependencies..." -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    Write-Host "✅ pubspec.yaml found" -ForegroundColor Green
    
    # Check if dependencies are installed
    if ((Test-Path ".dart_tool") -and (Test-Path "pubspec.lock")) {
        Write-Host "✅ Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Dependencies not installed" -ForegroundColor Yellow
        Write-Host "   Run: flutter pub get" -ForegroundColor White
        $Warnings++
    }
} else {
    Write-Host "❌ pubspec.yaml not found" -ForegroundColor Red
    Write-Host "   Are you in the project directory?" -ForegroundColor White
    $Errors++
}
Write-Host ""

# Check Firebase configuration
Write-Host "🔥 Checking Firebase Configuration..." -ForegroundColor Yellow
$firebaseFiles = 0

if (Test-Path "android/app/google-services.json") {
    Write-Host "✅ Android Firebase config found" -ForegroundColor Green
    $firebaseFiles++
}

if (Test-Path "ios/Runner/GoogleService-Info.plist") {
    Write-Host "✅ iOS Firebase config found" -ForegroundColor Green
    $firebaseFiles++
}

if (Test-Path "lib/firebase_options.dart") {
    Write-Host "✅ Flutter Firebase options found" -ForegroundColor Green
    $firebaseFiles++
}

if ($firebaseFiles -eq 0) {
    Write-Host "⚠️  No Firebase configuration files found" -ForegroundColor Yellow
    Write-Host "   App will use default configuration" -ForegroundColor White
    $Warnings++
}
Write-Host ""

# Check Windows Long Paths (Windows-specific)
Write-Host "🪟 Checking Windows Long Paths..." -ForegroundColor Yellow
try {
    $longPathsEnabled = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue
    if ($longPathsEnabled.LongPathsEnabled -eq 1) {
        Write-Host "✅ Long paths enabled" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Long paths not enabled (may cause issues with deep folder structures)" -ForegroundColor Yellow
        Write-Host "   Run as Administrator:" -ForegroundColor White
        Write-Host '   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force' -ForegroundColor Gray
        $Warnings++
    }
} catch {
    Write-Host "⚠️  Could not check long paths setting" -ForegroundColor Yellow
    $Warnings++
}
Write-Host ""

# Run flutter doctor
Write-Host "🏥 Running Flutter Doctor..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
flutter doctor
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

# Check for common issues
Write-Host "🔍 Checking for Common Issues..." -ForegroundColor Yellow

# Check Java (for Android builds)
try {
    $javaVersion = java -version 2>&1 | Select-Object -First 1
    Write-Host "✅ Java installed: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Java not found" -ForegroundColor Yellow
    Write-Host "   Required for Android builds" -ForegroundColor White
    $Warnings++
}
Write-Host ""

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📊 Health Check Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

if ($Errors -eq 0 -and $Warnings -eq 0) {
    Write-Host "✅ All checks passed! Your environment is ready." -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 You can now run:" -ForegroundColor Cyan
    Write-Host "   flutter pub get" -ForegroundColor White
    Write-Host "   flutter run" -ForegroundColor White
} elseif ($Errors -eq 0) {
    Write-Host "⚠️  $Warnings warning(s) found" -ForegroundColor Yellow
    Write-Host "   Your environment should work, but some features may be limited." -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 You can try running:" -ForegroundColor Cyan
    Write-Host "   flutter pub get" -ForegroundColor White
    Write-Host "   flutter run" -ForegroundColor White
} else {
    Write-Host "❌ $Errors critical error(s) found" -ForegroundColor Red
    Write-Host "⚠️  $Warnings warning(s) found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⛔ Please fix the errors above before running the app." -ForegroundColor Red
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

if ($Errors -gt 0) {
    exit 1
} else {
    exit 0
}
