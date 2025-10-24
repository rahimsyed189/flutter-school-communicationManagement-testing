#!/bin/bash

# School Management System - Quick Run Script (Linux/macOS)
# This script sets up and runs the project with one command

set -e

echo "🚀 School Management System - Quick Start"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed!"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Check for devices
echo ""
echo "📱 Available devices:"
flutter devices

# Run the app
echo ""
echo "🎯 Starting app..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
flutter run

echo ""
echo "✅ Done!"
