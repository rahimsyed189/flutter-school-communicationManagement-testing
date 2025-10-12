# Current Page Background Image Feature

## Overview
Admins can now upload custom background images for the "Current Page" (admin_home_page.dart). The image is stored in Cloudflare R2 storage and displayed as a **FULL-PAGE BACKGROUND** covering the entire screen including header, icons, and all content.

## Features

### 1. Admin Background Image Upload Page
- **Location**: `lib/admin_background_image_page.dart`
- **Access**: Admin Settings → Background Image
- **Functionality**:
  - View current background image (or default gradient)
  - Upload new background image to R2 storage
  - Remove existing background image
  - Image stored in `currentPageBackgroundImage/` folder in R2

### 2. Dynamic Full-Page Background Display
- **Location**: `lib/admin_home_page.dart`
- **Functionality**:
  - Fetches background image URL from Firestore (`app_config/current_page_background`)
  - Displays image using `cached_network_image` covering **ENTIRE PAGE**
  - Background covers: header, title, grid icons, announcements, groups - everything
  - Semi-transparent gradient overlay for better content readability
  - Falls back to purple-blue gradient if image fails to load or doesn't exist
  - Automatically reloads after admin uploads/removes background

### 3. Firestore Structure
```
app_config (collection)
  └── current_page_background (document)
      ├── imageUrl: "https://...r2.cloudflarestorage.com/currentPageBackgroundImage/..."
      ├── uploadedAt: Timestamp
      └── fileName: "image.jpg"
```

### 4. R2 Storage Structure
```
R2 Bucket (schoolcommstorage)
  └── currentPageBackgroundImage/
      └── {timestamp}_{filename}
```

## Usage Instructions

### For Admins:
1. Open the app and navigate to "Current Page"
2. Tap the Settings icon (⚙️) in the top-right
3. Select "Background Image" from the menu
4. Tap "Select Image" to choose an image
5. Tap "Upload to R2" to upload
6. Return to Current Page - the background will cover the entire screen!

### Visual Experience:
- **Header**: White title "Current Page" on background image
- **Content Area**: All icons, cards, and content appear over the background
- **Overlay**: Semi-transparent gradient (dark at top, light at bottom) ensures text readability
- **Fallback**: Beautiful purple-blue gradient if no image uploaded

## Technical Details

### Dependencies Used:
- `cached_network_image: ^3.4.0`: For efficient image loading and caching
- `file_picker`: For image selection
- `minio`: For R2/S3 uploads
- `cloud_firestore`: For storing image URL
- `wakelock_plus`: Keep device awake during upload

### Architecture:
- **Stack-based layout**: Background image at bottom layer, content on top
- **Positioned.fill**: Ensures background covers entire screen
- **Gradient overlay**: Three-stop gradient (dark → medium → light) from top to bottom
- **Responsive**: Works on all screen sizes

### Files Modified:
1. `lib/admin_background_image_page.dart` (NEW)
   - Complete upload/management page
   - Preview current background
   - R2 upload with progress
   - Remove background option

2. `lib/admin_home_page.dart` (MODIFIED)
   - Restructured to use Stack layout
   - Full-page background with Positioned.fill
   - Gradient overlay for readability
   - Cached image loading
   - Maintained all existing functionality

3. `pubspec.yaml` (MODIFIED)
   - Added `cached_network_image: ^3.4.0`

4. `BACKGROUND_IMAGE_FEATURE.md` (NEW)
   - This documentation file

## Best Practices Implemented:
✅ Full-page background image coverage
✅ Image caching for performance  
✅ Gradient overlay for text readability
✅ Gradient fallback for reliability
✅ Loading states during upload
✅ Error handling
✅ File size recommendations (landscape 16:9, max 2MB)
✅ Wakelock during upload to prevent interruption
✅ Automatic refresh after upload/remove
✅ Clean Stack-based architecture

## Design Pattern:
```dart
Scaffold(
  body: Stack(
    children: [
      // Layer 1: Background Image (full screen)
      Positioned.fill(child: CachedNetworkImage(...)),
      
      // Layer 2: Gradient Overlay (for readability)
      Positioned.fill(child: Container(gradient: ...)),
      
      // Layer 3: Content (header + scrollable content)
      Column(
        children: [
          Container(height: 160), // Header
          Expanded(...),           // Content
        ],
      ),
    ],
  ),
)
```
