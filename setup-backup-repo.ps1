# PowerShell script to create backup repository
param(
    [string]$BackupRepoName = "flutter-school-communicationManagement-backup",
    [string]$GitHubUser = "rahimsyed189"
)

Write-Host "Setting up backup repository: $BackupRepoName" -ForegroundColor Green

# Check if GitHub CLI is available
$ghAvailable = Get-Command "gh" -ErrorAction SilentlyContinue
if ($ghAvailable) {
    Write-Host "Using GitHub CLI to create backup repository..." -ForegroundColor Yellow
    
    # Create the backup repository using GitHub CLI
    try {
        gh repo create $BackupRepoName --private --description "Backup of Flutter School Communication Management System"
        Write-Host "✅ Backup repository created successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Repository might already exist or creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ GitHub CLI not found. You'll need to create the backup repo manually at:" -ForegroundColor Yellow
    Write-Host "https://github.com/new" -ForegroundColor Cyan
    Write-Host "Repository name: $BackupRepoName" -ForegroundColor Cyan
    Write-Host "Make it private and don't initialize with README" -ForegroundColor Cyan
    Read-Host "Press Enter after creating the repository on GitHub..."
}

# Add backup remote
$backupUrl = "https://github.com/$GitHubUser/$BackupRepoName.git"
Write-Host "Adding backup remote: $backupUrl" -ForegroundColor Yellow

git remote remove backup 2>$null # Remove if exists
git remote add backup $backupUrl

# Push to backup repository
Write-Host "Pushing to backup repository..." -ForegroundColor Yellow
try {
    git push backup main --force
    Write-Host "✅ Successfully pushed to backup repository!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to push to backup repository. Please check your credentials." -ForegroundColor Red
    Write-Host "You may need to authenticate with GitHub or check the repository URL." -ForegroundColor Yellow
}

Write-Host "`n🎉 Setup complete! Your repositories:" -ForegroundColor Green
Write-Host "Original: https://github.com/$GitHubUser/flutter-school-communicationManagement-system" -ForegroundColor Cyan
Write-Host "Backup:   https://github.com/$GitHubUser/$BackupRepoName" -ForegroundColor Cyan

Write-Host "`nFuture updates:" -ForegroundColor Yellow
Write-Host "  git push origin main     # Update original repo" -ForegroundColor White
Write-Host "  git push backup main     # Update backup repo" -ForegroundColor White
Write-Host "  git push origin main && git push backup main  # Update both" -ForegroundColor White