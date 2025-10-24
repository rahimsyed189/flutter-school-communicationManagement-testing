# 🎓 School Management & Communication System

A comprehensive Flutter-based school management system with multi-school support, real-time communication, media sharing, and cloud storage integration.

---

## ⚡ Quick Start (Any OS)

### Prerequisites
- Flutter SDK 3.24.0 or higher
- Dart SDK (included with Flutter)
- Git

### One-Command Setup & Run

#### Windows (PowerShell):
```powershell
# Check environment
.\doctor.ps1

# Run app
.\run.ps1
```

#### Linux/macOS (Bash):
```bash
# Check environment
./doctor.sh

# Run app
./run.sh
```

#### Manual Setup:
```bash
flutter pub get
flutter run
```

---

## 📁 Project Structure

```
flutterapp/
├── lib/                          # Main application code
│   ├── main.dart                # App entry point
│   ├── services/                # Business logic & utilities
│   │   ├── school_context.dart  # Multi-school management
│   │   └── dynamic_firebase_options.dart
│   ├── *_page.dart             # UI screens
│   └── firebase_options.dart   # Firebase configuration
├── android/                     # Android-specific files
├── ios/                        # iOS-specific files
├── web/                        # Web-specific files
├── windows/                    # Windows-specific files
├── linux/                      # Linux-specific files
├── macos/                      # macOS-specific files
├── functions/                  # Firebase Cloud Functions
├── pubspec.yaml               # Dependencies
├── .flutter-version           # Flutter version lock
├── SETUP.md                   # Detailed setup guide
├── doctor.ps1 / doctor.sh     # Environment checker
└── run.ps1 / run.sh           # Quick run scripts
```

---

## 🌟 Features

### 🏫 Multi-School Management
- ✅ Complete data isolation per school
- ✅ School-specific folders in R2 storage
- ✅ Unique School IDs for access control
- ✅ Auto-provisioning during registration

### 📢 Communication
- ✅ Announcements with rich media
- ✅ Group messaging
- ✅ Real-time chat
- ✅ Push notifications (FCM)
- ✅ Custom notification templates

### 📁 Media Management
- ✅ Image upload (R2/Cloudflare storage)
- ✅ Video upload with compression
- ✅ Thumbnail generation
- ✅ YouTube integration
- ✅ School-specific media folders

### 👥 User Management
- ✅ Role-based access (Admin, Teacher, Student)
- ✅ User approval system
- ✅ Profile management
- ✅ Session management

### 🗂️ Academic Management
- ✅ Class management
- ✅ Subject assignment
- ✅ Student enrollment
- ✅ Staff directory

### 🎨 UI/UX
- ✅ Material Design 3
- ✅ Responsive layouts
- ✅ Dark/Light theme support
- ✅ Custom background images
- ✅ Google-style form inputs

### 🔒 Security
- ✅ Firebase Authentication
- ✅ Firestore security rules
- ✅ schoolId-based data isolation
- ✅ Composite indexes for queries

### 🧹 Maintenance
- ✅ Auto-cleanup of old media
- ✅ Configurable retention policies
- ✅ Cache management
- ✅ Storage optimization

---

## 🚀 Deployment

### Mobile

#### Android:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### iOS (macOS only):
```bash
flutter build ios --release
# Then archive in Xcode
```

### Desktop

#### Windows:
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

#### macOS:
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/
```

#### Linux:
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

## 🔧 Configuration

### Firebase Setup
1. Create Firebase project at https://console.firebase.google.com
2. Enable services:
   - Authentication (Email/Password, Google Sign-In)
   - Firestore Database
   - Cloud Storage
   - Cloud Messaging
3. Download config files:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)
   - Update `lib/firebase_options.dart` (all platforms)

### Cloudflare R2 Setup (Optional)
1. Create R2 bucket at https://dash.cloudflare.com
2. Get API credentials
3. Configure in app (Admin Settings → R2 Configuration)

---

## 📚 Documentation

- **[SETUP.md](SETUP.md)** - Complete setup instructions for all platforms
- **[R2_SCHOOL_ISOLATION.md](R2_SCHOOL_ISOLATION.md)** - R2 storage architecture
- **[SCHOOL_NOTIFICATIONS_TEMPLATE_README.md](SCHOOL_NOTIFICATIONS_TEMPLATE_README.md)** - Notification system
- **[AI_FORM_BUILDER_README.md](AI_FORM_BUILDER_README.md)** - Dynamic forms
- **[DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md)** - Deployment checklist

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

---

## 🐛 Troubleshooting

### Common Issues

**"Flutter command not found"**
```bash
# Add Flutter to PATH (see SETUP.md for details)
```

**"Version solving failed"**
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

**"Gradle build failed"**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**Syntax errors after git pull**
```bash
flutter analyze
dart fix --apply
```

---

## 📊 Performance

- **Optimized for 10,000+ schools**
- **School-specific data isolation**
- **Composite Firestore indexes**
- **Efficient R2 storage structure**
- **Lazy loading & pagination**
- **Image/video caching**

---

## 🔄 Updating

```bash
# Update dependencies
flutter pub upgrade

# Update Flutter SDK
flutter upgrade

# Check for outdated packages
flutter pub outdated
```

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

---

## 📝 License

This project is proprietary software. All rights reserved.

---

## 📞 Support

For issues or questions:
- Check documentation in project `.md` files
- Run environment checker: `./doctor.sh` or `.\doctor.ps1`
- Contact project maintainers

---

## ✅ System Requirements

| Platform | Minimum | Recommended |
|----------|---------|-------------|
| Flutter  | 3.24.0  | Latest stable |
| Dart     | 3.5.0   | Latest |
| Android  | API 21+ | API 33+ |
| iOS      | 12.0+   | 15.0+ |
| Windows  | 10      | 11 |
| macOS    | 10.15+  | 13.0+ |
| Linux    | Ubuntu 20.04+ | Ubuntu 22.04+ |

---

## 🎯 Key Technologies

- **Frontend**: Flutter 3.24.0
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **Storage**: Cloudflare R2 / Firebase Storage
- **Notifications**: Firebase Cloud Messaging
- **State Management**: setState (StatefulWidget)
- **Architecture**: MVC-inspired
- **Database**: Cloud Firestore (NoSQL)

---

**Built with ❤️ for educational institutions worldwide**
