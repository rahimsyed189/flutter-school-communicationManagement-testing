# Auto-Create Firebase Project Feature - Setup Guide

## 🎯 Feature Overview

This feature allows school admins to automatically create their own Firebase projects with a single button click. The admin:
1. Clicks "Auto-Create Firebase Project"
2. Signs in with their Google account
3. Waits 2-3 minutes
4. Gets all API keys auto-filled automatically!

## 📋 Prerequisites

The admin's Google account needs:
- Google Cloud Platform access (free tier is fine)
- Permissions to create projects
- Billing enabled (Firebase free tier doesn't charge unless you exceed limits)

## 🚀 Setup Instructions

### Step 1: Deploy the Cloud Function

1. **Navigate to functions directory:**
   ```powershell
   cd functions
   ```

2. **Install dependencies:**
   ```powershell
   npm install
   ```

3. **Deploy the function:**
   ```powershell
   firebase deploy --only functions:createFirebaseProject
   ```

4. **Copy the deployed URL** - You'll see output like:
   ```
   ✔  functions[createFirebaseProject(us-central1)] Deployed
   Function URL: https://us-central1-YOUR-PROJECT.cloudfunctions.net/createFirebaseProject
   ```

### Step 2: Update Flutter App with Cloud Function URL

1. Open `lib/school_registration_page.dart`

2. Find line ~165 (in `_autoCreateFirebaseProject` method):
   ```dart
   final cloudFunctionUrl = 'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createFirebaseProject';
   ```

3. Replace with your actual Cloud Function URL from Step 1

4. Save the file

### Step 3: Update Google Sign-In Configuration

#### For Web:
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to **APIs & Services > Credentials**
4. Edit your OAuth 2.0 Client ID
5. Add authorized JavaScript origins:
   - `http://localhost` (for local testing)
   - Your production domain
6. Add authorized redirect URIs:
   - `http://localhost/auth` (for local testing)
   - Your production redirect URI

#### For Android:
1. Get your SHA-1 fingerprint:
   ```powershell
   cd android
   ./gradlew signingReport
   ```
2. Add SHA-1 to Firebase Console:
   - Firebase Console > Project Settings > Your Android App
   - Add the SHA-1 fingerprint

#### For iOS:
1. Download the updated `GoogleService-Info.plist`
2. Replace in `ios/Runner/GoogleService-Info.plist`

### Step 4: Enable Required APIs in Google Cloud

The admin's Google account needs these APIs enabled (they'll be prompted automatically, but you can pre-enable):

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable these APIs:
   - Firebase Management API
   - Cloud Resource Manager API
   - Service Usage API
   - Identity Toolkit API
   - Cloud Firestore API

### Step 5: Test the Feature

1. **Run the app:**
   ```powershell
   flutter run
   ```

2. **Navigate to School Registration:**
   - Admin Home > Register School

3. **Test auto-creation:**
   - Enter school name
   - Toggle "Configure Firebase" ON
   - Click "Auto-Create Firebase Project"
   - Sign in with a Google account that has GCP permissions
   - Wait 2-3 minutes
   - Verify all fields auto-fill!

## 🔧 Troubleshooting

### Error: "Google Sign-In cancelled or failed"
**Solution:** User cancelled the sign-in or doesn't have proper permissions. Make sure:
- User approves all requested permissions
- User's Google account has access to Google Cloud Platform

### Error: "Failed to create Firebase project"
**Solution:** Check Cloud Function logs:
```powershell
firebase functions:log --only createFirebaseProject
```

Common issues:
- User doesn't have billing enabled
- User hit project creation limit (max 30 projects per account)
- Required APIs not enabled

### Error: "Operation timeout"
**Solution:** Project creation takes time. The timeout is set to 5 minutes. If it fails:
- Check if project was partially created in Google Cloud Console
- Try again with a different project ID
- Check Cloud Function logs for detailed error

### Fields not auto-filling
**Solution:** 
- Check browser console for errors
- Verify Cloud Function URL is correct in code
- Check that response format matches expected structure

## 📱 User Experience

### What the admin sees:

1. **Before clicking:**
   - "Auto-Create Firebase Project" button
   - Description: "Sign in with your Google account to automatically create a new Firebase project"

2. **During creation:**
   - Progress updates:
     - Step 1/5: Signing in with Google...
     - Step 2/5: Generating project ID...
     - Step 3/5: Creating Firebase project... (This may take 2-3 minutes)
     - Step 4/5: Parsing configuration...
     - Step 5/5: Auto-filling forms...

3. **After success:**
   - ✅ Success message with project ID
   - All form fields auto-populated
   - Ready to click "Register School"

## 🔐 Security Considerations

### User's OAuth Token
- Token is only used to create projects under their own account
- Token is never stored
- Token expires after use

### Project Ownership
- Each school admin owns their Firebase project
- They control billing and usage
- They can manage it in Google Cloud Console

### API Scopes Requested
- `cloud-platform`: Full access to Google Cloud (needed to create projects)
- `firebase`: Firebase Management API access
- `cloudplatformprojects`: Project creation permissions

## 💡 Alternative: Manual Entry

If auto-creation doesn't work or admin prefers manual setup:
1. Admin can still manually enter API keys
2. Platform tabs (Web, Android, iOS, macOS, Windows) remain available
3. They can copy-paste from Firebase Console

## 🎓 What Gets Created Automatically?

When admin clicks "Auto-Create Firebase Project", the system creates:

1. **Google Cloud Project** with unique ID
2. **Firebase Project** linked to that Cloud Project
3. **Web App** with API keys
4. **Android App** with configuration
5. **iOS App** with configuration
6. **Firestore Database** initialized
7. **Firebase Auth** enabled
8. **Cloud Messaging** enabled

All configurations are returned and auto-filled in the form!

## 📊 Cost Implications

### For School Admins:
- Firebase Free Tier is generous
- Typical school usage stays within free limits
- If exceeded, costs are minimal ($1-5/month for small schools)

### What's Free:
- Firebase Auth: 50K verifications/month
- Firestore: 50K reads/day, 20K writes/day, 1GB storage
- Cloud Storage: 5GB storage, 1GB downloads/day
- Hosting: 10GB storage, 360MB downloads/day

## 🔄 Next Steps After Setup

1. Deploy Cloud Function
2. Update Cloud Function URL in code
3. Test with a Google account that has GCP access
4. Document the URL for your team
5. Consider adding the URL to environment variables or Firebase Remote Config

## 📞 Support

If issues persist:
1. Check Cloud Function logs: `firebase functions:log`
2. Check browser console for client-side errors
3. Verify Google Cloud Console for partially created projects
4. Test with a different Google account
5. Ensure billing is enabled on the admin's Google Cloud account

---

**Note:** This feature requires the admin to have a Google account with Google Cloud Platform permissions. For users without GCP access, they can still manually enter Firebase configuration or you can implement the "Master Service Account" approach where you create projects for them.
