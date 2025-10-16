# Scaffold Layout Crash Fix

## Issue Description
After clicking "🔑 Load My Firebase Projects", the app would freeze and crash with hundreds of rendering exceptions:

```
EXCEPTION CAUGHT BY RENDERING LIBRARY
The _ScaffoldLayout custom multichild layout delegate tried to lay out the child with id "_ScaffoldSlot.snackBar" more than once.
Each child must be laid out exactly once.

RenderFlex children have non-zero flex but incoming width constraints are unbounded.
RenderBox was not laid out: RenderFlex#4bea6
Cannot hit test a render box that has never been laid out.
```

### Root Cause
The `_loadUserFirebaseProjects()` method was:
1. **Calling `setState()` multiple times in rapid succession** (lines 189-192 and 194-197)
2. **Showing SnackBar immediately during layout phase** without waiting for frame completion
3. **Not clearing previous SnackBars** causing multiple SnackBars to stack and conflict

This caused the Scaffold to attempt laying out the SnackBar widget multiple times during the same frame, which violates Flutter's layout rules.

## Solution Applied

### 1. Combined Multiple setState Calls
**Before (BROKEN):**
```dart
setState(() {
  _isLoadingProjects = false;
  _creationProgress = '';
});

// ... some logic ...

setState(() {
  _userProjects = projects;
  _selectedProjectId = null;
});

ScaffoldMessenger.of(context).showSnackBar(...); // Immediate during layout!
```

**After (FIXED):**
```dart
// Single setState call
setState(() {
  _isLoadingProjects = false;
  _creationProgress = '';
  _userProjects = projects;
  _selectedProjectId = null;
});

// Show SnackBar AFTER frame completes
if (mounted) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  });
}
```

### 2. Added Safety Checks
- **`if (mounted)` checks** - Ensures widget is still in tree before showing SnackBar
- **`clearSnackBars()`** - Removes any existing SnackBars before showing new one
- **`addPostFrameCallback()`** - Waits for layout to complete before showing SnackBar

### 3. Applied Fix to All SnackBar Usages

#### Methods Fixed:
1. **`_loadUserFirebaseProjects()`**:
   - Success case (projects loaded)
   - Empty case (no projects found)
   - Error case (exception thrown)

2. **`_verifySelectedProject()`**:
   - Validation errors (no project selected, no token)
   - Success case (project configured)
   - Error case (configuration failed)

## Technical Explanation

### Why This Happens
Flutter's rendering pipeline has strict rules:
1. **Each child must be laid out exactly once per frame**
2. **Layout phase must complete before showing overlays** (like SnackBars)
3. **Multiple setState() calls in rapid succession** can trigger multiple layout passes

When you call `setState()` → `setState()` → `showSnackBar()` synchronously:
- First setState triggers layout pass #1
- Second setState triggers layout pass #2 (overlapping with #1)
- SnackBar tries to insert during layout → CRASH

### Why addPostFrameCallback Fixes It
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  // This runs AFTER the current frame's layout is complete
  ScaffoldMessenger.of(context).showSnackBar(...);
});
```

This ensures:
- ✅ Layout phase completes fully
- ✅ Scaffold is in stable state
- ✅ SnackBar can be added without conflicts
- ✅ No multiple layout attempts

### Why clearSnackBars Helps
```dart
ScaffoldMessenger.of(context).clearSnackBars(); // Remove old ones first
ScaffoldMessenger.of(context).showSnackBar(...);  // Show new one
```

This prevents:
- ❌ Stacking multiple SnackBars
- ❌ Conflicting SnackBar animations
- ❌ Layout thrashing from multiple overlays

## Testing Results

### Before Fix:
```
✅ Google Sign-In successful
✅ Found 2 Firebase project(s)
❌ CRASH - Hundreds of rendering exceptions
❌ Page completely frozen
❌ Cannot interact with UI
```

### After Fix:
```
✅ Google Sign-In successful
✅ Found 2 Firebase project(s)
✅ SnackBar shows cleanly
✅ Dropdown populates with projects
✅ UI fully responsive
✅ No rendering errors
```

## Files Modified
- `lib/school_registration_page.dart` (lines 159-350)
  - Fixed: `_loadUserFirebaseProjects()` method
  - Fixed: `_verifySelectedProject()` method
  - Pattern: All SnackBar calls now use `addPostFrameCallback()` + `clearSnackBars()`

## Prevention Pattern

**Use this pattern for ALL SnackBars shown after async operations:**

```dart
// Step 1: Update state once
setState(() {
  _isLoading = false;
  _data = newData;
});

// Step 2: Show SnackBar after frame completes
if (mounted) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Success!')),
      );
    }
  });
}
```

## Related Issues Fixed
- **Input Method Editor (IME) spamming**: The repeated layout crashes were causing IME to toggle rapidly
- **Background GC thrashing**: Layout crashes triggered excessive garbage collection (139ms pauses)
- **UI thread blocking**: Rendering exceptions blocked all user interaction

## Commit Message
```
fix: resolve Scaffold layout crash when loading Firebase projects

- Combined multiple setState() calls into single update
- Use addPostFrameCallback() to show SnackBars after layout completes
- Add clearSnackBars() to prevent stacking conflicts
- Add mounted checks for safety
- Apply pattern to all SnackBar usages in registration page

Fixes: RenderBox layout exceptions, IME toggle spam, frozen UI after sign-in
```

---

**Date Fixed**: October 16, 2025
**Issue Severity**: CRITICAL (app unusable after sign-in)
**Fix Complexity**: MEDIUM (pattern application across multiple methods)
**Testing Status**: ✅ VERIFIED (manual testing on Android)
