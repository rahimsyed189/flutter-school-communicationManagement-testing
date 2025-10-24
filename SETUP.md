# School Management System - Setup Guide

## ✅ System Requirements

### Supported Operating Systems
- ✅ Windows 10/11
- ✅ macOS 10.15+
- ✅ Linux (Ubuntu 20.04+, Fedora, etc.)

### Required Software
- **Flutter SDK**: 3.24.0 or higher
- **Dart SDK**: Included with Flutter
- **Git**: Latest version
- **IDE**: VS Code, Android Studio, or IntelliJ IDEA

---

## 🚀 Quick Start (Any OS)

### Step 1: Install Flutter

#### Windows:
```powershell
# Download Flutter SDK
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip" -OutFile "flutter.zip"
Expand-Archive flutter.zip -DestinationPath C:\src\
[System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\src\flutter\bin", "User")
```

#### macOS/Linux:
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Add to shell profile (~/.bashrc, ~/.zshrc, etc.)
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Step 2: Verify Installation
```bash
flutter doctor
```

Expected output should show:
- ✅ Flutter (Channel stable, 3.24.0)
- ✅ Android toolchain
- ✅ Chrome (for web development)
- ✅ VS Code or Android Studio

### Step 3: Clone & Setup Project

```bash
# Navigate to project directory
cd /path/to/flutterapp

# Get dependencies
flutter pub get

# Run code generation (if needed)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4: Run the App

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or run on default device
flutter run
```

---

## 🔧 Project-Specific Setup

### 1. Firebase Configuration

The app uses Firebase. Ensure you have:

**Option A: Use Existing Firebase (Recommended for Testing)**
- The app already has default Firebase configuration
- No additional setup needed for testing

**Option B: Configure Your Own Firebase**
1. Create a Firebase project at https://console.firebase.google.com
2. Enable Firestore, Authentication, Storage
3. Download configuration files:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Web: Update `lib/firebase_options.dart`

### 2. R2 Storage (Optional - For Media Upload)

If using Cloudflare R2 for media storage:
1. Get R2 credentials from Cloudflare dashboard
2. Configure in app (Admin Settings → R2 Configuration)

### 3. Platform-Specific Setup

#### Windows:
```powershell
# Enable Windows desktop
flutter config --enable-windows-desktop

# Build for Windows
flutter build windows
```

#### macOS:
```bash
# Enable macOS desktop
flutter config --enable-macos-desktop

# Install CocoaPods
sudo gem install cocoapods

# Build for macOS
flutter build macos
```

#### Linux:
```bash
# Enable Linux desktop
flutter config --enable-linux-desktop

# Install Linux dependencies
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Build for Linux
flutter build linux
```

#### Android:
- Android Studio with Android SDK installed
- Accept Android licenses: `flutter doctor --android-licenses`

#### iOS (macOS only):
- Xcode 14.0 or higher
- CocoaPods: `sudo gem install cocoapods`

---

## 🐛 Troubleshooting

### Common Issues

#### 1. "Flutter command not found"
**Solution**: Add Flutter to your PATH
```bash
# Windows (PowerShell as Admin)
[System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\src\flutter\bin", "Machine")

# macOS/Linux
export PATH="$PATH:$HOME/flutter/bin"
```

#### 2. "Gradle build failed"
**Solution**: 
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 3. "CocoaPods not installed" (macOS/iOS)
**Solution**:
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter run
```

#### 4. "Version solving failed"
**Solution**:
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

#### 5. "Build failed with exit code 1"
**Solution**: Check syntax errors
```bash
flutter analyze
dart fix --apply
```

#### 6. Long Windows Path Issues
**Solution**: Enable long paths
```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

---

## 📦 Dependencies

All dependencies are managed in `pubspec.yaml`. Key packages:

### Core
- `flutter` - UI framework
- `cloud_firestore` - Database
- `firebase_auth` - Authentication
- `firebase_storage` - File storage

### Media
- `video_player` - Video playback
- `video_compress` - Video compression
- `image_picker` - Image/video picker
- `file_picker` - File selection

### Storage
- `minio` - R2/S3 client
- `shared_preferences` - Local storage
- `path_provider` - File system paths

### UI
- `flutter_local_notifications` - Notifications
- `cached_network_image` - Image caching

---

## 🚦 Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/widget_test.dart
```

---

## 📱 Building for Production

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (macOS only)
```bash
flutter build ios --release
# Then open Xcode to archive and upload
```

### Windows
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

### macOS
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/
```

### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### Web
```bash
flutter build web --release
# Output: build/web/
```

---

## 🔄 Updating Dependencies

```bash
# Update all packages
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name

# Check outdated packages
flutter pub outdated
```

---

## 📋 Pre-Flight Checklist

Before running on a new machine:

- [ ] Flutter SDK installed (3.24.0+)
- [ ] `flutter doctor` shows no critical issues
- [ ] Project dependencies installed (`flutter pub get`)
- [ ] Firebase configuration present
- [ ] Required platform tools installed
- [ ] Device/emulator available
- [ ] Internet connection (for first run)

---

## 🆘 Getting Help

If you encounter issues:

1. **Check Flutter Doctor**: `flutter doctor -v`
2. **Clean Build**: `flutter clean && flutter pub get`
3. **Check Logs**: `flutter run --verbose`
4. **Search Issues**: Check GitHub Issues or Stack Overflow
5. **Contact Support**: Refer to project maintainers

---

## 📝 Environment Variables (Optional)

For CI/CD or automated builds, set:

```bash
# Flutter/Dart SDK paths
export FLUTTER_ROOT="/path/to/flutter"
export DART_SDK="$FLUTTER_ROOT/bin/cache/dart-sdk"
export PATH="$PATH:$FLUTTER_ROOT/bin"

# Android (if building for Android)
export ANDROID_HOME="/path/to/android-sdk"
export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools"

# Java (for Android builds)
export JAVA_HOME="/path/to/java"
```

---

## 🎯 Quick Commands Reference

```bash
# Essential commands
flutter doctor                  # Check setup
flutter pub get                # Install dependencies
flutter run                    # Run app
flutter clean                  # Clean build files
flutter analyze                # Check for issues
flutter test                   # Run tests

# Platform builds
flutter build apk              # Android APK
flutter build ios              # iOS
flutter build web              # Web
flutter build windows          # Windows
flutter build macos            # macOS
flutter build linux            # Linux

# Development
flutter pub upgrade            # Update packages
flutter channel stable         # Switch to stable channel
flutter upgrade               # Update Flutter SDK
```

---

## ✅ System is Ready When:

1. `flutter doctor` shows all green checkmarks (or at least no red X's)
2. `flutter pub get` completes without errors
3. `flutter run` launches the app successfully
4. You can see the login/registration screen

**Estimated Setup Time**: 15-30 minutes (first time)

---

## 📞 Support

For project-specific issues, contact the development team or refer to:
- **Documentation**: See `README.md` and other `.md` files in project root
- **Flutter Docs**: https://docs.flutter.dev
- **Firebase Docs**: https://firebase.google.com/docs
