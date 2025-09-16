#!/bin/bash

# Firebase Functions Setup Script for Server-Side Cleanup

echo "🚀 Setting up Firebase Functions for Server-Side Cleanup..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Navigate to functions directory
cd functions

echo "📦 Installing dependencies..."
npm install

echo "🔧 Setting up Firebase configuration..."
echo "Please enter your R2/S3 credentials:"

read -p "R2 Endpoint (e.g., https://account-id.r2.cloudflarestorage.com): " R2_ENDPOINT
read -p "R2 Access Key ID: " R2_ACCESS_KEY_ID
read -s -p "R2 Secret Access Key: " R2_SECRET_ACCESS_KEY
echo
read -p "R2 Bucket Name: " R2_BUCKET_NAME

# Set Firebase config
echo "⚙️ Configuring Firebase environment variables..."
firebase functions:config:set r2.endpoint="$R2_ENDPOINT"
firebase functions:config:set r2.access_key_id="$R2_ACCESS_KEY_ID"
firebase functions:config:set r2.secret_access_key="$R2_SECRET_ACCESS_KEY"
firebase functions:config:set r2.bucket_name="$R2_BUCKET_NAME"

echo "🚀 Deploying Firebase Functions..."
firebase deploy --only functions

echo "✅ Setup complete! Your server-side cleanup is now active."
echo ""
echo "📋 Next steps:"
echo "1. Open your Flutter app"
echo "2. Go to Admin menu > Server Cleanup"
echo "3. Configure cleanup settings"
echo "4. Monitor cleanup logs"
echo ""
echo "📅 Cleanup will run daily at 2 AM UTC automatically."
