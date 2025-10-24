# School-Specific Background Images

## Overview
Background images are now school-specific. Each school can set its own custom background image that appears on announcements and group chat pages. **Old background images are kept** for history/rollback, and settings are **cached locally** for instant display.

## Changes Made

### 1. **admin_background_image_page.dart**
- **R2 Storage Path**: Changed from `currentPageBackgroundImage/` to `schools/{SCHOOL_ID}/background/`
- **Firestore Path**: Changed from `app_config/current_page_background` to `schools/{SCHOOL_ID}/config/background`
- **No Deletion**: Old background images are kept in R2 (not deleted on new upload)
- **Local Cache**: Background URL cached by school ID in SharedPreferences
- **All Settings**: Now stored per school:
  - `schools/{SCHOOL_ID}/config/background` - Image URL
  - `schools/{SCHOOL_ID}/config/background_gradient` - Gradient colors
  - `schools/{SCHOOL_ID}/config/background_image_fit` - Image alignment
  - `schools/{SCHOOL_ID}/config/background_image_opacity` - Image transparency
  - `schools/{SCHOOL_ID}/config/background_apply_to` - Page selection

### 2. **announcements_page.dart**
- Added background image support with gradient fallback
- **Cache-First Loading**: Loads from cache instantly, then updates from Firestore
- Background loads automatically based on current school ID
- Uses cached network image for performance
- Transparent Scaffold to show background
- Settings cached locally: URL, opacity, gradient colors

### 3. **group_chat_page.dart**
- Added background image support (same as announcements)
- **Cache-First Loading**: Instant display from cache
- Background loads automatically based on current school ID
- Consistent look across announcements and group chats
- Transparent UI elements to show background

## How It Works

### For Admins
1. Go to **Admin Panel** → **Background Image**
2. Upload a custom background image (recommended: 16:9 landscape, max 2MB)
3. The image is saved to R2 at `schools/{YOUR_SCHOOL_ID}/background/` 
4. **Old images are kept** - each upload creates a new file with timestamp
5. Configure:
   - **Image opacity**: 5% to 100% (default 20% for readability)
   - **Gradient colors**: Fallback gradient when image loads
   - **Image alignment**: Cover, Contain, Fill, Fit Width, or Fit Height

### For Users
- Background automatically appears on:
  - **Announcements page**: Custom background behind all announcements
  - **Group chat pages**: Same background for consistent experience
- **Instant Display**: Loads from cache immediately on subsequent opens
- **Auto-Update**: Checks Firestore for latest background and updates cache
- No configuration needed - uses school's settings

## Caching Strategy

### Local Cache (SharedPreferences) by School ID:
- `background_url_{SCHOOL_ID}` - Background image URL
- `background_opacity_{SCHOOL_ID}` - Image opacity
- `background_color1_{SCHOOL_ID}` - Gradient color 1
- `background_color2_{SCHOOL_ID}` - Gradient color 2

### Loading Process:
1. **First Load**: Check cache → Load from cache instantly → Fetch from Firestore → Update cache if changed
2. **Subsequent Loads**: Show cached data immediately → Fetch latest from Firestore in background → Update if changed

### Benefits:
- **Instant Display**: Background appears immediately (no loading delay)
- **Always Fresh**: Updates from Firestore to get latest changes
- **School Isolation**: Cache keys include school ID (multi-school safe)
- **Offline Support**: Shows cached background even without internet

## Technical Details

### Data Structure
```
Firestore:
└── schools/
    └── {SCHOOL_ID}/
        └── config/
            ├── background
            │   ├── imageUrl: string
            │   ├── uploadedAt: timestamp
            │   └── fileName: string
            ├── background_gradient
            │   ├── color1: int (Color value)
            │   ├── color2: int (Color value)
            │   └── updatedAt: timestamp
            ├── background_image_opacity
            │   ├── opacity: double (0.05 to 1.0)
            │   └── updatedAt: timestamp
            └── background_image_fit
                ├── fit: string ('cover', 'contain', etc.)
                └── updatedAt: timestamp

R2 Storage (keeps history):
└── schools/
    └── {SCHOOL_ID}/
        └── background/
            ├── {timestamp1}_{filename1}.jpg/png  (oldest)
            ├── {timestamp2}_{filename2}.jpg/png
            └── {timestamp3}_{filename3}.jpg/png  (latest/active)

SharedPreferences Cache:
├── background_url_{SCHOOL_ID}: string
├── background_opacity_{SCHOOL_ID}: double
├── background_color1_{SCHOOL_ID}: int
└── background_color2_{SCHOOL_ID}: int
```

### Upload Process:
1. Admin selects image
2. Upload to R2 at `schools/{SCHOOL_ID}/background/{timestamp}_{filename}`
3. **No deletion** - old images remain in R2
4. Save new URL to Firestore: `schools/{SCHOOL_ID}/config/background`
5. Cache URL locally: `SharedPreferences['background_url_{SCHOOL_ID}']`
6. All users of school see new background on next load

### Loading Process (First Time):
1. Check cache for `background_url_{SCHOOL_ID}` → **Not found**
2. Fetch from Firestore: `schools/{SCHOOL_ID}/config/background`
3. Display background from URL
4. Cache URL locally for next time

### Loading Process (Subsequent Times):
1. Check cache for `background_url_{SCHOOL_ID}` → **Found!**
2. Display cached background **immediately** (instant)
3. Fetch from Firestore in background
4. If URL changed, update cache and refresh display
5. If same, keep showing cached version

### Performance
- **Cached images**: Uses `cached_network_image` for fast loading
- **Gradient fallback**: Shows instantly while image loads
- **Lazy loading**: Background loads in background, doesn't block UI
- **School isolation**: Each school's background is completely separate
- **Instant display**: Cache ensures background shows immediately on app open
- **History preserved**: Old backgrounds kept in R2 for rollback if needed

### Default Behavior
If no background image is set:
- Shows gradient background (default: purple to pink)
- Gradient colors can be customized per school
- Clean, professional look maintained

## Benefits

1. **Complete School Isolation**: Each school has its own background
2. **Brand Customization**: Schools can use their logo/colors as background
3. **Consistent Experience**: Same background on announcements and chats
4. **Performance Optimized**: Cached images, gradient fallback, instant display
5. **Simple Setup**: Upload once, appears everywhere
6. **No User Action Required**: Background applies automatically for all school users
7. **History Preserved**: Old backgrounds kept in R2 (can rollback if needed)
8. **Instant Display**: Cache ensures no loading delay on app open
9. **Offline Support**: Shows cached background even without internet
10. **Multi-School Safe**: Cache keys include school ID (different schools = different cache)

## Migration Notes

- **Old backgrounds**: If you had a global background set before, each school needs to upload their own
- **Backward compatible**: Works with schools that don't have background set (shows gradient)
- **Old images preserved**: Previous background images remain in R2 storage
- **Cache automatically managed**: No manual cache clearing needed - auto-updates when background changes

## Rollback Instructions

If you need to restore a previous background:

1. Get the old image URL from R2 storage: `schools/{SCHOOL_ID}/background/`
2. Manually update Firestore: `schools/{SCHOOL_ID}/config/background` with old `imageUrl`
3. Clear cache on users' devices or wait for auto-update
4. Old background will reappear

OR simply upload a new background - old ones are never deleted.
