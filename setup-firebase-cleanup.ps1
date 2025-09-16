# Firebase Functions Setup Script for Server-Side Cleanup (Windows)

Write-Host "🚀 Setting up Firebase Functions for Server-Side Cleanup..." -ForegroundColor Green

# Check if Firebase CLI is installed
try {
    firebase --version | Out-Null
    Write-Host "✅ Firebase CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found. Installing..." -ForegroundColor Red
    npm install -g firebase-tools
}

# Navigate to functions directory
Set-Location functions

Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
npm install

Write-Host "🔧 Setting up Firebase configuration..." -ForegroundColor Yellow
Write-Host "Please enter your R2/S3 credentials:" -ForegroundColor Cyan

$R2_ENDPOINT = Read-Host "R2 Endpoint (e.g., https://account-id.r2.cloudflarestorage.com)"
$R2_ACCESS_KEY_ID = Read-Host "R2 Access Key ID"
$R2_SECRET_ACCESS_KEY = Read-Host "R2 Secret Access Key" -AsSecureString
$R2_SECRET_ACCESS_KEY_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($R2_SECRET_ACCESS_KEY))
$R2_BUCKET_NAME = Read-Host "R2 Bucket Name"

# Set Firebase config
Write-Host "⚙️ Configuring Firebase environment variables..." -ForegroundColor Yellow
firebase functions:config:set "r2.endpoint=$R2_ENDPOINT"
firebase functions:config:set "r2.access_key_id=$R2_ACCESS_KEY_ID"
firebase functions:config:set "r2.secret_access_key=$R2_SECRET_ACCESS_KEY_PLAIN"
firebase functions:config:set "r2.bucket_name=$R2_BUCKET_NAME"

Write-Host "🚀 Deploying Firebase Functions..." -ForegroundColor Yellow
firebase deploy --only functions

Write-Host "✅ Setup complete! Your server-side cleanup is now active." -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Open your Flutter app"
Write-Host "2. Go to Admin menu > Server Cleanup"
Write-Host "3. Configure cleanup settings"
Write-Host "4. Monitor cleanup logs"
Write-Host ""
Write-Host "📅 Cleanup will run daily at 2 AM UTC automatically." -ForegroundColor Green
