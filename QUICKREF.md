# 🚀 Quick Reference - Run Project on Any Machine

## ⚡ TL;DR - Get Running Fast

### Windows (PowerShell):
```powershell
# Option 1: Check & Run (Recommended)
.\doctor.ps1    # Check environment
.\run.ps1       # Run app

# Option 2: Manual
flutter pub get
flutter run
```

### Linux/macOS (Bash):
```bash
# Option 1: Check & Run (Recommended)
./doctor.sh     # Check environment
./run.sh        # Run app

# Option 2: Manual
flutter pub get
flutter run
```

---

## 📋 Pre-Flight Checklist

### Must Have ✅
- [ ] Flutter SDK 3.24.0+ installed
- [ ] Git installed
- [ ] In project directory (`flutterapp/`)

### Nice to Have ⭐
- [ ] Android Studio (for Android)
- [ ] Xcode (for iOS, macOS only)
- [ ] VS Code with Flutter extension

---

## 🔧 One-Time Setup

### 1. Install Flutter
**Windows:**
```powershell
# Download from https://flutter.dev
# Extract to C:\src\flutter
# Add to PATH: C:\src\flutter\bin
```

**macOS/Linux:**
```bash
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

### 2. Verify Installation
```bash
flutter doctor
```

### 3. Get Project Dependencies
```bash
cd /path/to/flutterapp
flutter pub get
```

---

## 🎯 Run Commands

### Default Device
```bash
flutter run
```

### Specific Platform
```bash
flutter run -d windows    # Windows
flutter run -d chrome     # Web browser
flutter run -d macos      # macOS
flutter run -d linux      # Linux
```

### With Options
```bash
flutter run --release     # Release mode
flutter run --profile     # Profile mode (performance)
flutter run --verbose     # Detailed logs
```

---

## 🐛 Common Issues & Fixes

### "Flutter command not found"
```bash
# Add Flutter to PATH (see SETUP.md)
```

### "No devices found"
```bash
flutter devices          # List available
flutter emulators        # Android emulators
flutter emulators --launch <id>  # Start emulator
```

### "Gradle build failed"
```bash
cd android && ./gradlew clean && cd ..
flutter clean
flutter pub get
flutter run
```

### "Version solving failed"
```bash
flutter clean
rm pubspec.lock
flutter pub get
```

### Long path issues (Windows)
```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

---

## 📁 Files Created for Easy Setup

```
flutterapp/
├── .flutter-version       # Flutter version lock (3.24.0)
├── .tool-versions        # Version manager config
├── VERSION_INFO.md       # Complete version info
├── SETUP.md             # Detailed setup guide
├── README_QUICKSTART.md # Quick start guide
├── doctor.ps1           # Windows health check
├── doctor.sh            # Linux/macOS health check
├── run.ps1              # Windows quick run
├── run.sh               # Linux/macOS quick run
└── .vscode/
    ├── launch.json      # Debug configurations
    └── settings.json    # VS Code settings
```

---

## 🎓 What Each Script Does

### `doctor.ps1` / `doctor.sh`
✅ Checks Flutter installation  
✅ Verifies dependencies  
✅ Checks Firebase config  
✅ Runs `flutter doctor`  
✅ Reports any issues  

### `run.ps1` / `run.sh`
✅ Cleans previous builds  
✅ Gets dependencies  
✅ Lists available devices  
✅ Runs the app  

---

## 📖 Documentation Map

| File | Purpose |
|------|---------|
| `VERSION_INFO.md` | Complete version & dependency info |
| `SETUP.md` | Detailed multi-platform setup |
| `README_QUICKSTART.md` | Project overview & features |
| `R2_SCHOOL_ISOLATION.md` | Storage architecture |
| `DEPLOYMENT_STATUS.md` | Deployment checklist |

---

## 🔄 Daily Workflow

```bash
# Morning (first run of the day)
./doctor.sh              # Health check
flutter pub get          # Update deps

# Development
flutter run              # Start app
# (Make changes, hot reload with 'r')

# Before commit
flutter analyze          # Check code
flutter test             # Run tests
```

---

## 💡 Pro Tips

### VS Code Users
1. Open project in VS Code
2. Press `F5` to run with debugger
3. Use configured launch configs

### Performance Issues?
```bash
flutter run --profile    # Profile mode
flutter run --release    # Release mode (faster)
```

### Need Specific Device?
```bash
flutter devices          # See all
flutter run -d <device-id>
```

### Clean Everything
```bash
flutter clean
flutter pub get
flutter run
```

---

## ✅ Success Indicators

Your environment is ready when:
- ✅ `flutter doctor` shows no critical errors
- ✅ `flutter pub get` completes successfully
- ✅ `flutter run` launches app
- ✅ You see the login screen

---

## 🆘 Need Help?

1. **Run health check**: `./doctor.sh` or `.\doctor.ps1`
2. **Read docs**: Check `SETUP.md`
3. **Clean & retry**: `flutter clean && flutter pub get && flutter run`
4. **Check logs**: `flutter run --verbose`

---

## 🎯 What Makes This Project "Just Work"?

### Version Locking
- `.flutter-version` → Ensures correct Flutter version
- `.tool-versions` → Works with version managers (asdf, fvm)
- `pubspec.lock` → Locks all dependencies

### Health Checks
- `doctor.ps1` / `doctor.sh` → Pre-flight validation
- Automated dependency checking
- Firebase config verification

### Quick Scripts
- `run.ps1` / `run.sh` → One-command startup
- Automatic cleanup before run
- Device detection

### VS Code Integration
- `.vscode/launch.json` → Debug configs
- `.vscode/settings.json` → Formatter settings
- IntelliSense configured

### Documentation
- Clear, OS-specific instructions
- Troubleshooting guides
- Architecture documentation

---

## 🌍 Tested On

- ✅ Windows 10/11
- ✅ macOS 12+ (Intel & M1/M2)
- ✅ Ubuntu 20.04/22.04
- ✅ Fedora 35+

---

**Time to First Run**: ~2 minutes (after Flutter installed)  
**Time for Setup**: ~15-30 minutes (fresh machine)

**Ready to go? Run: `./doctor.sh` or `.\doctor.ps1`** 🚀
