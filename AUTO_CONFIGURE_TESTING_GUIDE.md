# 🧪 Auto-Configure Feature - Quick Test Guide

## ✅ Pre-Test Checklist
- [ ] All Cloud Functions deployed successfully
- [ ] Flutter app compiled without errors
- [ ] Test Firebase project available (with and without billing)
- [ ] Google account with Firebase project access

---

## 🎯 Test Scenario 1: Project WITHOUT Billing (Billing Gate Test)

### Setup:
1. Create a new Firebase project in Firebase Console
2. **DO NOT** enable billing (leave it on Spark plan)
3. Note the project ID

### Steps:
1. ✅ Open the school registration page in the app
2. ✅ Click "Load My Firebase Projects" button
3. ✅ Sign in with Google account
4. ✅ Verify projects load successfully
5. ✅ Select the test project WITHOUT billing from dropdown
6. ✅ Click "Verify & Configure" button

### Expected Results:
- ⏱️ Shows progress: "Step 1/4: Checking project..."
- ⏱️ Shows progress: "Step 2/4: Checking configuration..."
- 📱 **Billing instructions dialog appears:**
  - ⚠️ Title: "Billing Required"
  - 📋 Shows 6 numbered steps
  - 💚 Shows free tier information at bottom
  - 🔘 Has "Cancel" button
  - 🔘 Has "Open Firebase Console" button

### Dialog Content Verification:
```
✅ Step 1: Go to Firebase Console
✅ Step 2: Select Your Project
✅ Step 3: Upgrade to Blaze Plan
✅ Step 4: Link Billing Account
✅ Step 5: Set Budget Alert
✅ Step 6: Return to This App

✅ Free Tier Info:
   • Firestore: 50,000 reads/day
   • Auth: Unlimited users
   • Storage: 5GB downloads/day
   • FCM: Unlimited notifications
   
✅ "Typical usage for small schools: $0/month"
```

### Next Steps:
7. ✅ Click "Open Firebase Console" button
8. ✅ Enable billing in Firebase Console:
   - Go to project settings
   - Click "Upgrade" in bottom-left
   - Choose Blaze plan
   - Link billing account
   - Set budget alert at $5
9. ✅ Return to the app
10. ✅ Click "Verify & Configure" button again

### Expected Results After Enabling Billing:
- ⏱️ Shows progress: "Step 1/4: Checking project..."
- ⏱️ Shows progress: "Step 2/4: Checking configuration..."
- ⏱️ Shows progress: "Step 3/4: Fetching API keys..."
- ✅ Success snackbar appears:
  - "✅ Project 'your-project-id' configured!"
- 📝 All form fields auto-filled with API keys
- ❌ NO billing dialog appears

### ✅ Test Passed If:
- Billing dialog showed on first attempt
- Dialog had all 6 steps with clear instructions
- Free tier info displayed prominently
- Success and auto-fill after enabling billing

---

## 🎯 Test Scenario 2: Project WITH Billing (Direct Success)

### Setup:
1. Use existing Firebase project with billing enabled
2. Or use the project from Test 1 after enabling billing

### Steps:
1. ✅ Select project WITH billing from dropdown
2. ✅ Click "Verify & Configure" button

### Expected Results:
- ⏱️ Shows progress: "Step 1/4: Checking project..."
- ⏱️ Shows progress: "Step 2/4: Checking configuration..."
- ⏱️ Shows progress: "Step 3/4: Fetching API keys..."
- ✅ Success snackbar appears:
  - "✅ Project 'your-project-id' configured!"
  - Shows message about services enabled
- 📝 All form fields auto-filled:
  - ✅ Web API Key
  - ✅ Web Auth Domain
  - ✅ Web Project ID
  - ✅ Web Storage Bucket
  - ✅ Web Messaging Sender ID
  - ✅ Web App ID
- ❌ NO billing dialog appears
- ⏱️ Total time: ~5-10 seconds

### Firebase Console Verification:
1. Go to Firebase Console → Your Project
2. Verify services enabled:
   - ✅ Firestore
   - ✅ Authentication
   - ✅ Storage
   - ✅ Cloud Messaging

### ✅ Test Passed If:
- No billing dialog appeared
- Services auto-enabled in Firebase
- Forms auto-filled correctly
- Success message displayed

---

## 🎯 Test Scenario 3: Multiple Projects (Dropdown Test)

### Steps:
1. ✅ Click "Load My Firebase Projects"
2. ✅ Sign in if not already signed in
3. ✅ Verify projects load

### Expected Results:
- 📋 Dropdown shows list of all your Firebase projects
- 📋 Each project shows: `projectId (displayName)`
- 📋 Example: `adilabadautocabs (Adilabad Auto Cabs)`
- 🔵 "Load My Projects" button disabled while loading
- ✅ Blue checkmark or success message after loading

### Test Different Projects:
1. ✅ Select first project → Click "Verify & Configure"
2. ✅ Verify appropriate response (billing gate or success)
3. ✅ Select second project → Click "Verify & Configure"
4. ✅ Verify appropriate response
5. ✅ Verify forms update with new project's keys

### ✅ Test Passed If:
- All projects listed correctly
- Can switch between projects
- Each project verifies independently
- Forms update for each project

---

## 🎯 Test Scenario 4: Error Handling

### Test 4A: Invalid Project Selection
1. ✅ Clear project selection (if possible)
2. ✅ Click "Verify & Configure" without selecting project

**Expected:** Orange snackbar: "⚠️ Please select a project from the dropdown"

### Test 4B: No Sign-In
1. ✅ Reload app (clear auth token)
2. ✅ Try to verify without loading projects

**Expected:** Orange snackbar: "⚠️ Please sign in first by clicking 'Load My Projects'"

### Test 4C: Network Error
1. ✅ Disable internet connection
2. ✅ Try to verify project

**Expected:** Red snackbar with network error message

### Test 4D: Invalid Access Token
1. ✅ Wait for token to expire (1 hour)
2. ✅ Try to verify project

**Expected:** Error message about expired token

### ✅ Test Passed If:
- All errors handled gracefully
- Clear error messages displayed
- No app crashes
- User knows what to do next

---

## 🎯 Test Scenario 5: UI/UX Verification

### Billing Dialog UI Checks:
- [ ] Dialog has orange warning icon (⚠️)
- [ ] Dialog title: "Billing Required"
- [ ] Dialog scrollable if content long
- [ ] Numbered steps have circular blue badges (①②③④⑤⑥)
- [ ] Step titles are bold
- [ ] Step actions are normal text
- [ ] Warnings have orange ⚠️ icon
- [ ] Free tier box has green background
- [ ] Free tier limits bulleted
- [ ] "Typical usage" text is bold
- [ ] "Cancel" button on left
- [ ] "Open Firebase Console" button on right (orange)
- [ ] "Open Firebase Console" has external link icon

### Progress Indicators:
- [ ] Progress text shows while loading
- [ ] Progress updates through steps
- [ ] Loading spinner visible
- [ ] Button disabled while loading
- [ ] Clear feedback at each stage

### Success/Error Messages:
- [ ] Green snackbar for success
- [ ] Red snackbar for errors
- [ ] Orange snackbar for warnings
- [ ] Messages clear and actionable
- [ ] Duration appropriate (5-7 seconds)

---

## 📊 Test Results Template

```
┌────────────────────────────────────────────────────────┐
│ Auto-Configure Feature - Test Results                  │
├────────────────────────────────────────────────────────┤
│ Date: _____________                                    │
│ Tester: _____________                                  │
│ App Version: _____________                             │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Scenario 1: No Billing (Billing Gate)                 │
│   • Billing dialog appeared?         [ ]              │
│   • All 6 steps displayed?           [ ]              │
│   • Free tier info shown?            [ ]              │
│   • Success after billing enabled?   [ ]              │
│   Status: _______________                              │
│                                                        │
│ Scenario 2: With Billing (Direct Success)             │
│   • No billing dialog?               [ ]              │
│   • Services auto-enabled?           [ ]              │
│   • Forms auto-filled?               [ ]              │
│   • Success message shown?           [ ]              │
│   Status: _______________                              │
│                                                        │
│ Scenario 3: Multiple Projects                         │
│   • All projects loaded?             [ ]              │
│   • Can switch projects?             [ ]              │
│   • Forms update per project?        [ ]              │
│   Status: _______________                              │
│                                                        │
│ Scenario 4: Error Handling                            │
│   • No project selected handled?     [ ]              │
│   • No sign-in handled?              [ ]              │
│   • Network error handled?           [ ]              │
│   • Expired token handled?           [ ]              │
│   Status: _______________                              │
│                                                        │
│ Scenario 5: UI/UX                                      │
│   • Dialog UI correct?               [ ]              │
│   • Progress indicators work?        [ ]              │
│   • Messages clear?                  [ ]              │
│   Status: _______________                              │
│                                                        │
├────────────────────────────────────────────────────────┤
│ Overall Status: [ ] PASS  [ ] FAIL                     │
│                                                        │
│ Issues Found:                                          │
│ _________________________________________________      │
│ _________________________________________________      │
│ _________________________________________________      │
│                                                        │
│ Notes:                                                 │
│ _________________________________________________      │
│ _________________________________________________      │
│ _________________________________________________      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Test Command

```bash
# Run the app
flutter run
```

---

## 📝 Testing Tips

1. **Test with real accounts:** Use actual Firebase projects, not mocks
2. **Test both scenarios:** Projects with and without billing
3. **Check Firebase Console:** Verify services actually enabled
4. **Test on multiple devices:** Android, iOS, Web
5. **Take screenshots:** Document the billing dialog for records
6. **Test timing:** Note how long auto-configuration takes
7. **Verify costs:** Check Firebase billing after test (should be $0)

---

## ✅ Definition of Done

Feature is complete when:
- ✅ All 5 test scenarios pass
- ✅ No crashes or errors
- ✅ UI looks professional
- ✅ Billing dialog displays correctly
- ✅ Auto-configuration works reliably
- ✅ Error messages are clear
- ✅ Documentation is complete
- ✅ Code reviewed and approved

---

## 🎉 Success Criteria

**This feature is a success if:**
- Users never get stuck on billing requirements
- Clear guidance provided when billing needed
- Automatic configuration works when possible
- Free tier information reduces billing anxiety
- Overall setup time reduced by 70%+
- Zero confusion about next steps

---

## 📞 Support

If tests fail or issues found:
1. Check Cloud Function logs in Firebase Console
2. Check Flutter console for error messages
3. Verify internet connection
4. Verify Firebase project permissions
5. Review `AUTO_CONFIGURE_FEATURE.md` for details
