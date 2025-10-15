# Firebase Configuration Feature

## Overview

This feature allows administrators to dynamically configure Firebase API keys for all platforms (Web, Android, iOS, macOS, Windows) directly from the admin settings, without needing to modify `google-services.json`, `GoogleService-Info.plist`, or rebuild the app.

## Features

✅ **Dynamic Firebase Configuration** - Change Firebase projects on the fly
✅ **Multi-Platform Support** - Separate configurations for Web, Android, iOS, macOS, Windows
✅ **No JSON/Plist Files Required** - All configuration stored in Firestore
✅ **Default Fallback** - Uses firebase_options.dart values by default
✅ **Easy Toggle** - Switch between custom and default configs instantly
✅ **Secure Storage** - All configs stored in Firestore database
✅ **User-Friendly UI** - Clean interface with platform tabs
✅ **Reset Option** - One-click reset to default configuration

## How It Works

### 1. Default Configuration
- App starts with default Firebase configuration from `firebase_options.dart`
- These are the original API keys from the Flutter Firebase CLI setup

### 2. Custom Configuration
- Admin can enable "Use Custom Firebase Configuration" toggle
- Enter new Firebase API keys for each platform
- Save configuration to Firestore
- Restart app to apply changes

### 3. Configuration Storage
All custom configurations are stored in:
```
Firestore Collection: app_config
Document: firebase_config

Structure:
{
  "useCustomConfig": true/false,
  "lastUpdated": timestamp,
  "web": {
    "apiKey": "...",
    "appId": "...",
    "projectId": "...",
    ...
  },
  "android": { ... },
  "ios": { ... },
  "macos": { ... },
  "windows": { ... }
}
```

## Usage Guide

### Accessing Firebase Configuration

1. Open the app as Admin
2. Navigate to **Admin Settings**
3. Scroll to **API Configurations** section
4. Tap **Firebase Config**

### Configuring Firebase

#### Step 1: Get Firebase Credentials
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (or create a new one)
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll to **Your apps** section
5. Select your platform (Web, Android, iOS, etc.)
6. Copy the configuration values

#### Step 2: Enter Configuration
1. In Firebase Config page, toggle **Use Custom Firebase Configuration** to ON
2. Select the platform tab (Web, Android, iOS, etc.)
3. Fill in the required fields:
   - **API Key** - Your Firebase API Key
   - **App ID** - Firebase App ID
   - **Messaging Sender ID** - Cloud Messaging sender ID
   - **Project ID** - Firebase project ID
   - **Auth Domain** (Web/Windows) - yourproject.firebaseapp.com
   - **Database URL** (Optional) - Realtime Database URL
   - **Storage Bucket** (Optional) - yourproject.appspot.com
   - **Measurement ID** (Web/Windows) - Google Analytics ID
   - **iOS Bundle ID** (iOS/macOS) - Bundle identifier
   - **Android Client ID** (iOS/macOS) - Google Sign-In client ID

4. Repeat for all platforms you want to configure

#### Step 3: Save Configuration
1. Tap **Save Configuration** button
2. Wait for "Configuration saved!" message
3. **Restart the app** for changes to take effect

### Reset to Defaults
1. Tap the **⋮** menu in the top-right
2. Select **Reset to Defaults**
3. Confirm the action
4. Restart the app

## Platform-Specific Fields

### Web
- API Key ✓ (Required)
- App ID ✓ (Required)
- Messaging Sender ID ✓ (Required)
- Project ID ✓ (Required)
- Auth Domain
- Database URL
- Storage Bucket
- Measurement ID

### Android
- API Key ✓ (Required)
- App ID ✓ (Required)
- Messaging Sender ID ✓ (Required)
- Project ID ✓ (Required)
- Database URL
- Storage Bucket

### iOS / macOS
- API Key ✓ (Required)
- App ID ✓ (Required)
- Messaging Sender ID ✓ (Required)
- Project ID ✓ (Required)
- Database URL
- Storage Bucket
- iOS Bundle ID
- Android Client ID (for Google Sign-In)

### Windows
- API Key ✓ (Required)
- App ID ✓ (Required)
- Messaging Sender ID ✓ (Required)
- Project ID ✓ (Required)
- Auth Domain
- Database URL
- Storage Bucket
- Measurement ID

## Technical Implementation

### Files Created

1. **firebase_config_page.dart** - UI for Firebase configuration management
2. **services/dynamic_firebase_options.dart** - Service to load dynamic Firebase options

### Integration Points

The configuration is loaded during app initialization in `main.dart`:

```dart
import 'services/dynamic_firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with dynamic options
  await Firebase.initializeApp(
    options: await DynamicFirebaseOptions.getOptions(),
  );
  
  runApp(MyApp());
}
```

### How Dynamic Loading Works

1. **First Launch**: Uses default values from `firebase_options.dart`
2. **Subsequent Launches**: Checks Firestore for custom configuration
3. **Custom Config Found**: Uses custom values from Firestore
4. **Error/No Config**: Falls back to default values
5. **Cache**: Options are cached to avoid repeated Firestore reads

### Security Considerations

✅ **API Keys in Client Apps are Safe** - Firebase API keys are designed to be included in client apps
✅ **Security Rules Protect Data** - Firestore security rules control actual data access
✅ **Admin-Only Access** - Only admin users can modify Firebase configuration
✅ **Validation** - Required fields are validated before saving

### Performance

- **Cached Options**: Once loaded, options are cached in memory
- **One-Time Fetch**: Configuration fetched only once at app startup
- **Minimal Overhead**: Negligible impact on app startup time

## Troubleshooting

### Configuration Not Applied
- **Solution**: Restart the app completely (close and reopen)

### "Error loading configuration"
- **Solution**: Check Firestore permissions and network connectivity

### App Crashes After Changing Config
- **Solution**: Verify all required fields are filled correctly
- **Solution**: Reset to defaults and try again

### Can't Save Configuration
- **Solution**: Ensure you're logged in as admin
- **Solution**: Check Firestore security rules allow writes to `app_config/firebase_config`

### Google Sign-In Not Working
- **Solution**: Ensure Android Client ID is set for iOS/macOS platforms
- **Solution**: Verify OAuth client IDs in Firebase Console

## Firestore Security Rules

Add this rule to allow admins to manage Firebase configuration:

```javascript
// Firestore security rules
match /app_config/{document} {
  allow read: if true; // Everyone can read config
  allow write: if request.auth != null && 
               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

## Benefits

1. **No Rebuild Required** - Change Firebase projects without rebuilding the app
2. **Multi-Environment Support** - Easily switch between dev/staging/production
3. **User Control** - End users can configure their own Firebase project
4. **Testing Friendly** - Quick switching for testing different configurations
5. **No File Dependencies** - Eliminates need for google-services.json and GoogleService-Info.plist

## Limitations

1. **App Restart Required** - Changes require app restart to take effect
2. **Admin Access Only** - Only admin users should access this configuration
3. **Manual Entry** - All values must be entered manually (no JSON import yet)

## Future Enhancements

- [ ] JSON/Config file import feature
- [ ] Configuration validation/testing before save
- [ ] Multiple Firebase project profiles
- [ ] Export current configuration as JSON
- [ ] Configuration history/versioning
- [ ] Automatic app restart after configuration change

## Support

For questions or issues with Firebase configuration:
1. Check Firebase Console for correct values
2. Review Firestore security rules
3. Verify all required fields are filled
4. Try resetting to defaults
5. Check app logs for error messages

---

**Last Updated**: October 15, 2025
**Feature Version**: 1.0.0
