# iOS setup checklist

1) In Firebase Console
- Add iOS app with bundle id: com.adbsmalltech.adbapp
- Download GoogleService-Info.plist
- Upload APNs Auth Key (.p8) under Project Settings > Cloud Messaging

2) In Xcode (on a Mac)
- Open ios/Runner.xcworkspace
- Runner target > Signing & Capabilities:
  - Set your Team, ensure bundle id: com.adbsmalltech.adbapp
  - Add Push Notifications capability
  - Add Background Modes and enable Remote notifications
- Add GoogleService-Info.plist to Runner (ensure it’s in Copy Bundle Resources)

3) Build
- From project root on macOS:
  - flutter clean
  - cd ios && pod install && cd ..
  - flutter run -d <your iPhone>

Notes
- We already updated Info.plist and AppDelegate.swift for notifications.
- The Podfile is created with iOS 12.0 minimum.
- Client subscribes to topic 'all' after login; server-side send still needed (Cloud Function or Firebase Console).
