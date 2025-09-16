# Server-Side Cleanup Setup Guide

## Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Node.js installed for R2 cleanup script
- R2/S3 credentials configured

## 1. Deploy Firebase Functions

Navigate to your functions directory and deploy:
```bash
cd functions
firebase deploy --only functions
```

This will deploy the `dailyCleanup` function that runs at 2 AM UTC daily.

## 2. Setup R2 Cleanup Script

### Install dependencies:
```bash
cd scripts
npm install
```

### Configure environment variables:
Create a `.env` file in the scripts directory:
```
R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=your_bucket_name
```

### Download Firebase service account key:
1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Save as `firebase-service-account.json` in the scripts directory

### Test the R2 cleanup script:
```bash
npm run cleanup
```

## 3. Setup Cron Job for R2 Cleanup

### Linux/Mac:
```bash
# Edit crontab
crontab -e

# Add this line to run daily at 3 AM
0 3 * * * cd /path/to/your/scripts && npm run cleanup >> /var/log/r2-cleanup.log 2>&1
```

### Windows (Task Scheduler):
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger: Daily at 3:00 AM
4. Set action: Start a program
5. Program: `node`
6. Arguments: `r2-cleanup.js`
7. Start in: `C:\path\to\your\scripts`

## 4. Configure Cleanup Settings

1. Open your Flutter app
2. Go to Admin menu > Server Cleanup
3. Configure:
   - Cleanup frequency (daily/weekly/monthly)
   - What to clean (chats/announcements)
   - Enable R2 cleanup
4. Save settings

## 5. Monitor Cleanup Status

The app will show recent cleanup logs with:
- Success/failure status
- Number of items deleted
- Timestamps
- Error messages (if any)

## Troubleshooting

### Firebase Functions not running:
- Check Firebase Console > Functions for errors
- Verify function deployment: `firebase functions:log`

### R2 cleanup script errors:
- Check environment variables
- Verify R2 credentials
- Check log files: `/var/log/r2-cleanup.log`

### No cleanup logs in app:
- Verify Firestore rules allow writing to `cleanup_logs` collection
- Check Firebase service account permissions
