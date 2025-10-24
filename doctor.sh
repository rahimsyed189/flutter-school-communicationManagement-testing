#!/bin/bash

# School Management System - Pre-Flight Check Script
# This script checks if your environment is ready to run the project

echo "🏥 Running Environment Health Check..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check Flutter installation
echo "📱 Checking Flutter..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo -e "${GREEN}✅ Flutter installed: $FLUTTER_VERSION${NC}"
    
    # Check Flutter version
    REQUIRED_VERSION="3.24.0"
    CURRENT_VERSION=$(flutter --version | grep -oP "Flutter \K[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)
    
    if [[ "$CURRENT_VERSION" < "$REQUIRED_VERSION" ]]; then
        echo -e "${YELLOW}⚠️  Warning: Flutter version $CURRENT_VERSION is older than recommended $REQUIRED_VERSION${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ Flutter not found${NC}"
    echo "   Install from: https://flutter.dev/docs/get-started/install"
    ((ERRORS++))
fi
echo ""

# Check Dart
echo "🎯 Checking Dart..."
if command -v dart &> /dev/null; then
    DART_VERSION=$(dart --version 2>&1)
    echo -e "${GREEN}✅ Dart installed: $DART_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Dart not found (usually comes with Flutter)${NC}"
    ((WARNINGS++))
fi
echo ""

# Check Git
echo "📦 Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✅ Git installed: $GIT_VERSION${NC}"
else
    echo -e "${RED}❌ Git not found${NC}"
    echo "   Install from: https://git-scm.com/"
    ((ERRORS++))
fi
echo ""

# Check project dependencies
echo "📚 Checking Project Dependencies..."
if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}✅ pubspec.yaml found${NC}"
    
    # Check if dependencies are installed
    if [ -d ".dart_tool" ] && [ -f "pubspec.lock" ]; then
        echo -e "${GREEN}✅ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Dependencies not installed${NC}"
        echo "   Run: flutter pub get"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ pubspec.yaml not found${NC}"
    echo "   Are you in the project directory?"
    ((ERRORS++))
fi
echo ""

# Check Firebase configuration
echo "🔥 Checking Firebase Configuration..."
FIREBASE_FILES=0

if [ -f "android/app/google-services.json" ]; then
    echo -e "${GREEN}✅ Android Firebase config found${NC}"
    ((FIREBASE_FILES++))
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ iOS Firebase config found${NC}"
    ((FIREBASE_FILES++))
fi

if [ -f "lib/firebase_options.dart" ]; then
    echo -e "${GREEN}✅ Flutter Firebase options found${NC}"
    ((FIREBASE_FILES++))
fi

if [ $FIREBASE_FILES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No Firebase configuration files found${NC}"
    echo "   App will use default configuration"
    ((WARNINGS++))
fi
echo ""

# Run flutter doctor
echo "🏥 Running Flutter Doctor..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
flutter doctor
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for common issues
echo "🔍 Checking for Common Issues..."

# Check Android SDK (if on Linux/Mac)
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -z "$ANDROID_HOME" ]; then
        echo -e "${YELLOW}⚠️  ANDROID_HOME not set${NC}"
        echo "   Required for Android builds"
        ((WARNINGS++))
    fi
fi

# Check Java (for Android builds)
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    echo -e "${GREEN}✅ Java installed: $JAVA_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Java not found${NC}"
    echo "   Required for Android builds"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Health Check Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Your environment is ready.${NC}"
    echo ""
    echo "🚀 You can now run:"
    echo "   flutter pub get"
    echo "   flutter run"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    echo "   Your environment should work, but some features may be limited."
    echo ""
    echo "🚀 You can try running:"
    echo "   flutter pub get"
    echo "   flutter run"
else
    echo -e "${RED}❌ $ERRORS critical error(s) found${NC}"
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    echo ""
    echo "⛔ Please fix the errors above before running the app."
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit $ERRORS
