#!/usr/bin/env pwsh

# Push to testing repository only
# Usage: .\push-testing.ps1 [commit-message]

param(
    [string]$CommitMessage = "Testing update"
)

Write-Host "🧪 Pushing to testing repository..." -ForegroundColor Magenta

# Add all changes
Write-Host "📝 Adding changes..." -ForegroundColor Yellow
git add .

# Commit changes
Write-Host "💾 Committing changes: $CommitMessage" -ForegroundColor Yellow
git commit -m $CommitMessage

# Push to testing repository
Write-Host "📤 Pushing to testing repository..." -ForegroundColor Magenta
git push testing main
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to testing repository" -ForegroundColor Green
    Write-Host "🔗 Testing repo: https://github.com/rahimsyed189/flutter-school-communicationManagement-testing" -ForegroundColor White
} else {
    Write-Host "❌ Failed to push to testing repository" -ForegroundColor Red
    exit 1
}