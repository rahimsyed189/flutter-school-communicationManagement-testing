#!/usr/bin/env pwsh

# Push to all three repositories: original, backup, and testing
# Usage: .\push-all-three.ps1 [commit-message]

param(
    [string]$CommitMessage = "Update project"
)

Write-Host "🚀 Pushing to all three repositories..." -ForegroundColor Cyan

# Add all changes
Write-Host "📝 Adding changes..." -ForegroundColor Yellow
git add .

# Commit changes
Write-Host "💾 Committing changes: $CommitMessage" -ForegroundColor Yellow
git commit -m $CommitMessage

# Push to original repository
Write-Host "📤 Pushing to original repository..." -ForegroundColor Green
git push origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to original repository" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to push to original repository" -ForegroundColor Red
    exit 1
}

# Push to backup repository
Write-Host "📤 Pushing to backup repository..." -ForegroundColor Blue
git push backup main
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to backup repository" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to push to backup repository" -ForegroundColor Red
    exit 1
}

# Push to testing repository
Write-Host "📤 Pushing to testing repository..." -ForegroundColor Magenta
git push testing main
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to testing repository" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to push to testing repository" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 All repositories updated successfully!" -ForegroundColor Cyan
Write-Host "📋 Repository URLs:" -ForegroundColor White
Write-Host "   Original: https://github.com/rahimsyed189/flutter-school-communicationManagement-system" -ForegroundColor White
Write-Host "   Backup:   https://github.com/rahimsyed189/flutter-school-communicationManagement-backup" -ForegroundColor White
Write-Host "   Testing:  https://github.com/rahimsyed189/flutter-school-communicationManagement-testing" -ForegroundColor White