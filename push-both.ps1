# Dual Push Script for Backup and Original Repos

# This script pushes your changes to both repositories at once
Write-Host "📤 Pushing to both original and backup repositories..." -ForegroundColor Cyan

# Push to original repository
Write-Host "Pushing to ORIGINAL repository..." -ForegroundColor Yellow
git push origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Original repository updated successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to push to original repository" -ForegroundColor Red
}

# Push to backup repository  
Write-Host "Pushing to BACKUP repository..." -ForegroundColor Yellow
git push backup main

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backup repository updated successfully" -ForegroundColor Green
    Write-Host "🎉 Both repositories are now synchronized!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to push to backup repository" -ForegroundColor Red
}

Write-Host "`nRepository URLs:" -ForegroundColor Cyan
Write-Host "Original: https://github.com/rahimsyed189/flutter-school-communicationManagement-system" -ForegroundColor White
Write-Host "Backup:   https://github.com/rahimsyed189/flutter-school-communicationManagement-backup" -ForegroundColor White