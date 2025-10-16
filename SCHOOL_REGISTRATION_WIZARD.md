# School Registration Wizard - Step-by-Step UI

## Overview
Modern step-by-step wizard interface for school registration with a Google-style timeline UI.

## Features

### 🎯 4-Step Process

**Step 1: School Information**
- School name, admin details, email, phone
- Generates unique school key
- Success confirmation with copy button
- Auto-advances after successful creation

**Step 2: Firebase Project Selection**
- Load user's Firebase projects from Google account
- Dropdown selector for easy project selection
- Manual project ID input option
- "Verify & Auto-Configure" button
- Real-time billing status display:
  - Green card: Blaze plan (billing enabled) ✅
  - Orange card: Spark plan (billing not enabled) ⚠️
- Shows billing plan, account, and status

**Step 3: API Configuration**
- Platform tabs: Web, Android, iOS, macOS, Windows
- Platform-specific API key fields
- Auto-fill from Firebase verification
- Clean, organized layout

**Step 4: Review & Complete**
- Summary of all entered information
- School details review
- Firebase project summary
- Configured platforms list
- Final "Complete Registration" button

### ✨ UI/UX Improvements

#### Timeline-Style Stepper
- Visual progress indicator
- Completed steps marked with checkmarks
- Current step highlighted
- Can navigate between completed steps

#### Modern Design
- Clean Material Design 3 style
- Color-coded status cards:
  - Green: Success/Active
  - Orange: Warning/Requires attention
- Consistent spacing and typography
- Responsive layout

#### Smart Navigation
- "Continue" button advances to next step
- "Back" button returns to previous step
- Validation at each step before advancing
- Final "Complete Registration" button only on last step

#### Status Indicators
```dart
// Billing Status Card
Container with color-coded background:
  - Green background: Blaze plan (billing enabled)
  - Orange background: Spark plan (billing not enabled)
  
Shows:
  - Billing plan (Spark/Blaze)
  - Billing account name
  - Status (Active ✅ / Not Enabled ❌)
```

## Usage

### Importing the Wizard
```dart
import 'school_registration_wizard_page.dart';
```

### Navigation
```dart
// From anywhere in app
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const SchoolRegistrationWizardPage(),
  ),
);
```

### Integration with Existing Code
The wizard can replace the existing `SchoolRegistrationPage`:

**Option 1: Replace completely**
```dart
// In your navigation/routing
if (settings.name == '/schoolRegister') {
  return MaterialPageRoute(
    builder: (_) => const SchoolRegistrationWizardPage(),  // NEW
  );
}
```

**Option 2: Add as alternative**
```dart
// Keep both options
ElevatedButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => SchoolRegistrationWizardPage()),
  ),
  child: Text('New Registration (Wizard)'),
)
```

## Step Validation

### Step 1: School Info
- All fields validated before advancing
- School name required
- Admin name required
- Valid email format required
- School must be created successfully
- Shows generated key before advancing

### Step 2: Firebase Project
- Project ID required (dropdown or manual)
- Must verify project before advancing
- Billing status must be checked
- Auto-fills API keys if billing enabled

### Step 3: API Configuration
- No strict validation (optional)
- Can skip if already auto-filled
- Can modify auto-filled values

### Step 4: Review
- Read-only summary
- Complete button saves all data
- Shows success message
- Navigates back to previous screen

## API Integration

### Firebase Project Verification
```dart
await FirebaseProjectVerifier.autoConfigureFirebaseProject(
  accessToken,
  projectId,
);
```

**Response includes:**
- `billingEnabled`: true/false
- `billingPlan`: "Spark (Free)" or "Blaze (Pay as you go)"
- `billingAccountName`: Billing account ID
- `config`: Auto-filled API keys for all platforms

### School Registration
```dart
await FirebaseFirestore.instance
    .collection('school_registrations')
    .doc(schoolKey)
    .set({
      'schoolName': '...',
      'adminName': '...',
      'firebaseConfig': {...},
    });
```

## Visual Flow

```
┌─────────────────────────────────────┐
│  Step 1: School Information         │
│  ✅ Enter school details            │
│  ✅ Generate school key              │
└──────────────┬──────────────────────┘
               │ Continue
               ▼
┌─────────────────────────────────────┐
│  Step 2: Firebase Project           │
│  🔥 Load projects from Google       │
│  🔥 Select project from dropdown    │
│  🔥 Verify & check billing          │
│  ✅ Show plan: Blaze/Spark          │
└──────────────┬──────────────────────┘
               │ Continue
               ▼
┌─────────────────────────────────────┐
│  Step 3: API Configuration          │
│  ⚙️ Select platform (tabs)         │
│  ⚙️ Auto-filled API keys            │
│  ⚙️ Edit if needed                  │
└──────────────┬──────────────────────┘
               │ Continue
               ▼
┌─────────────────────────────────────┐
│  Step 4: Review & Complete          │
│  ✅ School info summary             │
│  ✅ Firebase project summary        │
│  ✅ Configured platforms            │
│  🎉 Complete Registration           │
└─────────────────────────────────────┘
```

## Benefits

### For Users
- **Clear progress**: Know exactly where they are
- **No confusion**: One task at a time
- **Error prevention**: Validation at each step
- **Visual feedback**: Green/orange status indicators
- **Confidence**: Review everything before completing

### For Developers
- **Modular**: Each step is independent
- **Maintainable**: Easy to add/remove steps
- **Reusable**: Step components can be extracted
- **Debuggable**: Clear state management

## Customization

### Adding a New Step
```dart
Step(
  title: const Text('New Step'),
  subtitle: const Text('Description'),
  content: _buildNewStepWidget(),
)
```

### Changing Colors
```dart
// In build method
colorScheme: ColorScheme.light(
  primary: Colors.blue.shade700,  // Change to your color
),
```

### Modifying Fields
Add/remove fields in `_buildSchoolRegistrationStep()` or other step builders.

## Testing Checklist

- [ ] Step 1: Create school and see generated key
- [ ] Step 2: Load Firebase projects successfully
- [ ] Step 2: Select project from dropdown
- [ ] Step 2: Verify project and see billing status
- [ ] Step 2: Green card for Blaze plan
- [ ] Step 2: Orange card for Spark plan
- [ ] Step 3: See auto-filled API keys
- [ ] Step 3: Edit API keys manually
- [ ] Step 4: Review shows all information
- [ ] Complete: Successfully saves and navigates back
- [ ] Back button: Works at all steps
- [ ] Validation: Can't skip required steps

## Screenshots (Conceptual)

**Step 1: School Info**
```
┌───────────────────────────────────┐
│ 🏫 School Information             │
│ Enter your school details         │
│                                   │
│ [School Name ____________]        │
│ [Admin Name _____________]        │
│ [Email __________________]        │
│                                   │
│ ✅ School Created!                │
│ Key: ABC123XYZ789                 │
│ [Copy Key]                        │
│                                   │
│ [Continue →]                      │
└───────────────────────────────────┘
```

**Step 2: Firebase Project**
```
┌───────────────────────────────────┐
│ 🔥 Connect Firebase Project       │
│                                   │
│ [Select Project ▼]                │
│ my-school-project                 │
│                                   │
│ [Verify & Auto-Configure]         │
│                                   │
│ ✅ Project Status (Green)         │
│ Plan: Blaze (Pay as you go)      │
│ Account: billing-12345            │
│ Status: Active ✅                 │
│                                   │
│ [Continue →] [← Back]             │
└───────────────────────────────────┘
```

---

**Created**: October 16, 2025
**File**: `lib/school_registration_wizard_page.dart`
**Type**: Flutter Widget (Stepper-based Wizard)
