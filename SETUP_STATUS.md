# Quick Setup Instructions

## ✅ COMPLETED:
- Firebase Functions deployed with `dailyCleanup` function
- Flutter UI created for server cleanup configuration
- AWS SDK integrated for R2 storage cleanup
- **NEW**: R2 credentials read from Firestore (`app_config/r2_settings`)

## 🔧 R2 CONFIGURATION (Automatic from Firestore):

The Firebase Function now reads R2 credentials directly from Firestore:
- Collection: `app_config`
- Document: `r2_settings`
- Fields needed:
  ```json
  {
    "endpoint": "https://YOUR-ACCOUNT-ID.r2.cloudflarestorage.com",
    "accessKeyId": "YOUR_ACCESS_KEY",
    "secretAccessKey": "YOUR_SECRET_KEY", 
    "bucketName": "YOUR_BUCKET_NAME"
  }
  ```

## 🚀 READY TO USE:

### Firebase Cleanup (Already Working):
- Runs daily at 2 AM UTC
- Deletes old chats and announcements
- Configurable via Flutter app

### R2 Storage Cleanup (Automatic):
- Uses existing R2 credentials from `app_config/r2_settings`
- No additional setup needed if R2 is already configured in your app

### How to Configure:
1. Open Flutter app
2. Admin menu > "Server Cleanup"
3. Set frequency (daily/weekly/monthly)
4. Choose what to clean (chats/announcements/R2)
5. Save settings

### Monitor Status:
- Check "Recent Cleanup Status" in the app
- View Firebase Console > Functions > Logs
- R2 cleanup will automatically work if credentials exist in Firestore

## 🎯 Current Status:
- ✅ Firebase Functions: ACTIVE & UPDATED
- ✅ Chat/Announcements Cleanup: READY
- ✅ R2 Storage Cleanup: AUTOMATIC (uses existing Firestore config)
- ✅ Flutter UI: READY
- ✅ No manual R2 setup needed!
