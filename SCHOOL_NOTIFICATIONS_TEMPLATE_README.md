# School Notifications Template

This template provides a comprehensive school notification system with media attachment capabilities, designed specifically for educational institutions.

## Features

### 📱 **School-Focused Notification Categories**
- 📢 General Announcement
- 📚 Academic Notice  
- 🎉 School Events
- 🚨 Emergency Alert
- ⚽ Sports Update
- 📝 Exam Schedule
- 🏖️ Holiday Notice

### 🎯 **Professional UI Design**
- Clean, intuitive interface designed for school administrators
- School-themed colors and icons
- Responsive layout that works on all devices
- Professional header with school branding area

### 📎 **Advanced Media Attachment System**
- **Multi-file support**: Attach multiple images, videos, documents, and audio files
- **Progress tracking**: Real-time upload progress with visual indicators
- **File type icons**: Automatic file type detection with appropriate icons
- **File size display**: Shows file sizes in MB for easy management
- **Remove files**: Easy removal of selected files before upload

### ☁️ **Cloud Storage Integration**
- **Cloudflare R2 Storage**: Secure, fast media hosting
- **Automatic file organization**: Files stored in organized folders by date
- **Direct URL generation**: Generate shareable links for all uploaded media
- **Configuration management**: Easy setup through admin settings

### 🔔 **Smart Notification System**
- **Firebase Integration**: Automatic push notifications to all devices
- **Notification Queue**: Reliable delivery system
- **Topic-based messaging**: Send to all students, specific classes, or groups
- **Timestamp tracking**: Automatic timestamping for all notifications

## How to Use

### 1. **Access the Template**
- Open the admin panel in your Flutter school management app
- Navigate to Settings (gear icon in top-right)
- Select "School Notifications" from the menu

### 2. **Create a Notification**
1. **Choose Category**: Select from predefined school notification categories
2. **Enter Title**: Add a clear, descriptive title for your notification
3. **Write Message**: Compose your notification content in the text area
4. **Attach Media** (Optional):
   - Click "Add Media" to select files
   - Choose multiple files (images, videos, documents, audio)
   - Preview selected files with sizes
   - Remove unwanted files with the X button

### 3. **Publish**
- Click "Publish School Notification" to send
- Media files are automatically uploaded to cloud storage
- Push notifications are sent to all connected devices
- Notification is saved in the school's communication database

## Upload Progress System

The template includes a comprehensive upload progress system:

- **Visual Progress Bar**: Shows real-time upload percentage
- **Status Messages**: Clear status updates during upload process
- **File-by-file Progress**: Individual progress for each file being uploaded
- **Error Handling**: Clear error messages if uploads fail
- **Background Processing**: Uses wake lock to prevent interruption

## Technical Integration

### Required Dependencies
```yaml
dependencies:
  flutter: ^3.0.0
  cloud_firestore: ^4.0.0
  file_picker: ^5.0.0
  minio: ^3.0.0
  wakelock_plus: ^1.0.0
  firebase_messaging: ^14.0.0
```

### Firebase Collections
The template automatically manages these Firestore collections:
- `school_notifications`: Stores all published notifications
- `notificationQueue`: Manages push notification delivery
- `app_config/r2_settings`: Stores Cloudflare R2 configuration

### Storage Structure
Media files are organized in Cloudflare R2 storage as:
```
school_notifications/
├── [timestamp]_0_filename.jpg
├── [timestamp]_1_document.pdf
└── [timestamp]_2_video.mp4
```

## Configuration Requirements

### Cloudflare R2 Setup
Before using media attachments, configure R2 storage in Admin Settings:
- Account ID
- Access Key ID  
- Secret Access Key
- Bucket Name
- Custom Domain (optional)

### Firebase Setup
Ensure Firebase is properly configured for:
- Firestore database
- Firebase Messaging for push notifications
- Authentication for admin access

## Security Features

- **Admin-only Access**: Only users with admin role can access this template
- **Secure File Upload**: All files uploaded through secure HTTPS connections
- **Access Control**: Firebase security rules control database access
- **Input Validation**: All form inputs are validated before processing

## Customization Options

The template can be easily customized:

### Categories
Modify the `_categories` list in the code to add/remove notification types:
```dart
final List<Map<String, String>> _categories = [
  {'value': 'custom', 'label': '🏫 Custom Category'},
  // Add your categories here
];
```

### Styling
Update colors, fonts, and layout by modifying the UI components in the `build()` method.

### File Types
Extend supported file types by updating the `_getMediaType()` and `_getFileIcon()` methods.

## Best Practices

### For School Administrators
1. **Use Clear Titles**: Make notification titles descriptive and specific
2. **Choose Appropriate Categories**: Select the most relevant category for each notification
3. **Optimize Media**: Compress large images/videos before upload to save bandwidth
4. **Test Notifications**: Send test notifications to verify functionality

### For Developers
1. **Error Handling**: Always wrap upload operations in try-catch blocks
2. **Progress Feedback**: Provide clear visual feedback during long operations
3. **Resource Management**: Properly dispose of controllers and disable wake locks
4. **Offline Handling**: Consider implementing offline capability for draft notifications

## Support and Maintenance

### Regular Maintenance
- Monitor Cloudflare R2 storage usage and costs
- Clean up old notification files periodically
- Update Firebase security rules as needed
- Review and update notification categories based on school needs

### Troubleshooting
- **Upload Failures**: Check R2 configuration and network connectivity
- **Missing Notifications**: Verify Firebase Messaging setup and device tokens
- **Permission Errors**: Ensure proper admin role validation
- **File Size Issues**: Check upload limits and available storage space

This template provides a complete, production-ready solution for school communication needs with robust media handling capabilities.
