# Route Persistence Feature Documentation

## Overview
This feature enables the app to remember and restore the last page a user was viewing when they reopen the app after closing it.

## How It Works

### 1. **Route Tracking Service** (`services/route_persistence_service.dart`)
- Saves the current route name and arguments to SharedPreferences
- Retrieves the last visited route on app start
- Clears saved routes on logout or when returning to home

### 2. **Navigation Updates** (`admin_home_page.dart`)
- **Announcements**: When tapped, saves `/announcements` route before navigating
- **Group Chats**: When a group is selected, saves `/groups/chat` route with group details
- **Home Page**: Automatically clears saved route when user lands on home page
- **Logout**: Clears saved route so next login starts fresh from home

### 3. **App Initialization** (`main.dart`)
- On app start, after successful session check:
  - Checks if there's a saved route
  - If found and valid, navigates to home first, then to the saved page
  - If not found, starts normally from home page

## User Experience

### Example Flow:
1. **User opens app** → Logs in → Sees Admin Home Page
2. **Taps Announcements** → Opens Announcements page
3. **Closes/kills the app**
4. **Reopens the app** → **Automatically opens Announcements page** ✅

### What Gets Persisted:
- ✅ Announcements page
- ✅ Group chat conversations (with group name and ID)
- ✅ User ID and role for proper context

### What Doesn't Get Persisted:
- ❌ Login page
- ❌ Admin home page (starts fresh if on home)
- ❌ Password change screens

## Technical Implementation

### Route Saving
```dart
// Before navigation
await RoutePersistenceService.saveRoute('/announcements', {
  'userId': widget.currentUserId,
  'role': widget.currentUserRole,
});
Navigator.pushNamed(context, '/announcements', arguments: args);
```

### Route Restoration
```dart
// On app start
final lastRoute = await RoutePersistenceService.getLastRoute();
final lastArgs = await RoutePersistenceService.getLastRouteArguments();

if (RoutePersistenceService.shouldRestoreRoute(lastRoute)) {
  Navigator.pushReplacementNamed(context, '/admin', arguments: {'userId': userId, 'role': role});
  await Future.delayed(const Duration(milliseconds: 100));
  Navigator.pushNamed(context, lastRoute!, arguments: lastArgs);
}
```

### Route Clearing
```dart
// On logout
await RoutePersistenceService.clearRoute();

// On home page load
@override
void initState() {
  super.initState();
  RoutePersistenceService.clearRoute();
}
```

## Future Enhancements

To add route persistence to other pages (Homework, Attendance, Exam, etc.):

1. Add the route to the navigation handler in `main.dart`
2. Update the `onTap` handler to save the route:
   ```dart
   onTap: () async {
     await RoutePersistenceService.saveRoute('/homework', {
       'userId': widget.currentUserId,
       'role': widget.currentUserRole,
     });
     Navigator.pushNamed(context, '/homework', arguments: {...});
   }
   ```

## Benefits
- ✅ Better user experience - users continue where they left off
- ✅ Faster access to frequently used sections
- ✅ Works across app restarts and device reboots
- ✅ Respects user privacy - cleared on explicit logout
- ✅ Automatic cleanup - cleared when returning to home page

## Testing Checklist
- [ ] Open Announcements, close app, reopen → Should open Announcements
- [ ] Open Group Chat, close app, reopen → Should open same Group Chat
- [ ] Navigate to Home, close app, reopen → Should start from Home
- [ ] Logout, login again → Should start from Home (cleared)
- [ ] Login as different user → Should respect their session and routes
