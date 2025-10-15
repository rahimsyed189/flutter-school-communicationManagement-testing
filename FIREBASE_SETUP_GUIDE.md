# 🚀 Firebase Setup Guide for Schools
## Complete Step-by-Step Instructions (5-7 minutes)

---

## 📋 Before You Start

**What you need:**
- ✅ A Google account (Gmail)
- ✅ 5-7 minutes of time
- ✅ A credit/debit card (for billing setup)
  - ⚠️ Don't worry! You WON'T be charged unless you exceed FREE limits
  - 💰 Small schools typically cost $0/month

**What you'll do:**
1. Create Firebase Project (2 min)
2. Set Up Billing Account (2 min) 
3. Enable Services (2 min)
4. Use our app to auto-fetch API keys (1 min)

---

# ⭐ PART 1: Create Firebase Project (2 minutes)

### Step 1: Go to Firebase Console
1. Open browser: **https://console.firebase.google.com**
2. **Sign in** with your Google account
   - ⚠️ Use the account you want to OWN this project

### Step 2: Create New Project
1. Click **"Add project"** (big button in center)
   - First time? Click **"Create a project"**

### Step 3: Enter Project Name
1. **Project name**: Type your school name
   - Example: "Little Star High School"
   - Example: "Green Valley Academy"
   
2. **Project ID** will appear below (auto-generated)
   - Example: `little-star-high-school-abc123`
   - ⚠️ **WRITE THIS DOWN!** You'll need it later!

3. Click **"Continue"**

### Step 4: Google Analytics
1. You'll see: "Enable Google Analytics for this project?"
2. **Toggle it OFF** (recommended - can enable later)
3. Click **"Create project"**

### Step 5: Wait
- Firebase creates your project (10-30 seconds)
- Progress bar will show creation status
- When done, click **"Continue"**

✅ **Part 1 Complete!** You now have a Firebase project.

---

# 💳 PART 2: Set Up Billing (2 minutes)

## Why is billing required?
Firebase requires a billing account for API access, but you get a **FREE tier**:
- 💰 Worth $10-25/month in FREE services
- 🎓 Small schools (100-500 users) = **$0/month**
- 📊 Only charged if you exceed free limits (rare!)

### Step 1: Upgrade to Blaze Plan
1. In Firebase Console, look for banner: **"Upgrade to Blaze plan"**
   - OR: Click ⚙️ **Settings** (bottom left) → **Usage and billing** tab → **Modify plan**

2. Select **"Blaze (Pay as you go)"**
3. Click **"Continue"**

### Step 2: Create Billing Account
**First time setting up billing?**

1. Click **"Create billing account"**
2. Select your **Country**
3. Check the box: **"I accept Terms of Service"**
4. Click **"Continue"**

**Already have a billing account?** → Skip to Step 3

### Step 3: Add Payment Method
1. Enter **Card Information**:
   - Card number
   - Expiration date  (MM/YY)
   - CVV (3 digits on back)
   - Cardholder name

2. Enter **Billing Address**:
   - Street address
   - City, State, ZIP code

3. Click **"Start my free trial"** or **"Submit"**

### Step 4: Set Budget Alert (RECOMMENDED!)
**Protect yourself from surprise charges:**

1. Open new tab: **https://console.cloud.google.com/billing**
2. Select your **billing account** from list
3. Click **"Budgets & alerts"** (left side menu)
4. Click **"CREATE BUDGET"**
5. Configure alert:
   - **Name**: "School App Alert"
   - **Projects**: Select your school project (check the box)
   - **Budget type**: Specified amount
   - **Target amount**: **$5.00** (or $10)
   - **Threshold rules**: 
     - 50% of budget (alert at $2.50)
     - 90% of budget (alert at $4.50)
     - 100% of budget (alert at $5.00)
   - **Email address**: Your email

6. Click **"FINISH"**

✅ **Part 2 Complete!** Billing is set up with protection.

---

# ⚙️ PART 3: Enable Services (2 minutes)

Return to **Firebase Console**: https://console.firebase.google.com

### Service 1: Firestore Database
1. Click **"Firestore Database"** (left menu)
2. Click **"Create database"** button
3. **Start mode**: Select **"Start in production mode"**
4. Click **"Next"**
5. **Cloud Firestore location**: Choose closest region
   - 🌏 **Asia**: `asia-south1` (Mumbai) or `asia-southeast1` (Singapore)
   - 🌎 **Americas**: `us-central1` (Iowa)
   - 🌍 **Europe**: `europe-west1` (Belgium)
6. Click **"Enable"**
7. Wait 10-20 seconds

✅ **Firestore enabled!**

### Service 2: Authentication
1. Click **"Authentication"** (left menu)
2. Click **"Get started"** button
3. Go to **"Sign-in method"** tab (top)
4. Find **"Email/Password"** in the list
5. Click on it
6. Toggle **"Enable"** to ON (switch turns blue)
7. Click **"Save"**

✅ **Authentication enabled!**

### Service 3: Storage
1. Click **"Storage"** (left menu)
2. Click **"Get started"** button
3. **Security rules**: Click **"Next"** (use defaults)
4. **Cloud Storage location**: Select SAME region as Firestore
5. Click **"Done"**

✅ **Storage enabled!**

### Service 4: Cloud Messaging
1. Click **"Cloud Messaging"** (left menu)
2. Click **"Get started"** button
3. Done! (FCM is auto-enabled)

✅ **Cloud Messaging enabled!**

---

# 📱 PART 4: Register Apps (1 minute)

### Register Web App (REQUIRED)
1. Click **⚙️ gear icon** (top left) → **"Project settings"**
2. Scroll down to **"Your apps"** section
3. Click the **Web icon** `</>`
4. **App nickname**: Enter "School Web App"
5. **DO NOT** check "Also set up Firebase Hosting"
6. Click **"Register app"**
7. You'll see code snippet → **IGNORE IT** (click "Continue to console")

✅ **Web app registered!**

### Register Android App (OPTIONAL)
**Only if you're using Android devices:**

1. In "Your apps" section, click **Android icon** 🤖
2. **Android package name**: 
   - Find in: `android/app/build.gradle`
   - Look for: `applicationId "com.example.app"`
   - Example: `com.yourschool.app`
3. **App nickname**: "School Android App"
4. Click **"Register app"**
5. **SKIP** downloading `google-services.json`
6. Click **"Next"** → **"Next"** → **"Continue to console"**

✅ **Android app registered!**

### Register iOS App (OPTIONAL)
**Only if you're using iOS devices:**

1. In "Your apps" section, click **iOS icon** 🍎
2. **iOS bundle ID**:
   - Find in: `ios/Runner.xcodeproj/project.pbxproj`
   - Look for: `PRODUCT_BUNDLE_IDENTIFIER`
   - Example: `com.yourschool.app`
3. **App nickname**: "School iOS App"
4. Click **"Register app"**
5. **SKIP** downloading `GoogleService-Info.plist`
6. Click **"Next"** → **"Next"** → **"Continue to console"**

✅ **iOS app registered!**

---

# 📲 PART 5: Use App to Auto-Fetch Keys (1 minute)

Now the magic happens - our app automatically fetches all API keys!

### Step 1: Open School Registration
1. Open the **School Management App**
2. Navigate to: **Admin Home** → **"Register School"**

### Step 2: Enter School Information
1. **School Name**: Your school's official name
2. **Admin Name**: Your full name
3. **Admin Email**: Your email address
4. **Admin Phone**: Your phone number

### Step 3: Enable Firebase Configuration
1. Find the switch: **"Configure Firebase"**
2. Toggle it **ON** (switch turns blue)
3. Firebase configuration section appears below

### Step 4: Enter Your Project ID
1. Look for: **"Firebase Project ID"** text field
2. Enter the Project ID you wrote down in Part 1
   - Example: `little-star-high-school-abc123`
3. **Forgot it?** 
   - Click the **"?"** help button
   - OR go to: Firebase Console → ⚙️ Settings → Project settings → Copy "Project ID"

### Step 5: Verify & Fetch Configuration
1. Click the big green button: **"Verify & Fetch Config"**
2. **Google Sign-In** popup appears
   - ⚠️ **IMPORTANT**: Sign in with the SAME Google account that owns the Firebase project!
3. Grant permissions when asked

### Step 6: Watch the Progress
You'll see these steps happen automatically:
- ✓ **Step 1/4**: Signing in with Google...
- ✓ **Step 2/4**: Verifying project setup...
- ✓ **Step 3/4**: Checking configuration...
- ✓ **Step 4/4**: Auto-filling forms...

⏱️ Takes about 10-15 seconds

### Step 7: Success!
When complete, you'll see a **green success message**:
> ✅ Project "your-project-id" verified!  
> All API keys have been auto-filled.

All configuration forms are now filled automatically! 🎉

### Step 8: Review (Optional)
Click through the tabs to see what was filled:
- **Web** tab: API Key, Auth Domain, Project ID, etc.
- **Android** tab: API keys and config (if you registered Android)
- **iOS** tab: API keys and config (if you registered iOS)

### Step 9: Register School
1. Scroll to the bottom
2. Click **"Register School"** button
3. You'll receive a unique **School Key**
   - Example: `SCHOOL-ABC123`
   - 💾 **SAVE THIS!**
4. Share the school key with:
   - ✅ Teachers (so they can join)
   - ✅ Students (so they can join)

✅ **DONE!** Your school is now registered and ready to use!

---

# ❌ Troubleshooting Common Issues

## Issue: "Project incomplete: Firestore not enabled"
**What happened**: Firestore was not created

**Fix**:
1. Go to Firebase Console
2. Complete **PART 3, Service 1** (Firestore Database)
3. Return to app and click "Verify & Fetch Config" again

---

## Issue: "Project incomplete: Web app not registered"
**What happened**: No web app in the project

**Fix**:
1. Go to Firebase Console
2. Complete **PART 4, Register Web App**
3. Return to app and click "Verify & Fetch Config" again

---

## Issue: "Billing not enabled"
**What happened**: Billing account not linked to project

**Fix**:
1. Go to Firebase Console → ⚙️ Settings → Usage and billing
2. Complete **PART 2** (Set Up Billing)
3. Return to app and click "Verify & Fetch Config" again

---

## Issue: "Permission denied" or "Access denied"
**What happened**: Signed in with wrong Google account

**Fix**:
1. In app, click "Verify & Fetch Config" again
2. When Google Sign-In appears:
   - Click your profile picture/avatar
   - Select **"Use another account"**
   - Sign in with the Google account that OWNS the Firebase project
3. Try verification again

---

## Issue: "Project not found"
**What happened**: Wrong Project ID or typo

**Fix**:
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Click ⚙️ **Settings** → **Project settings**
4. Find **"Project ID"** at the top
5. Copy it EXACTLY (select and Ctrl+C)
6. Paste into app's "Firebase Project ID" field
7. Try verification again

---

## Issue: Multiple things missing
**What happened**: Skipped some setup steps

**Fix**: The app will show you a list of what's missing:
```
❌ Project incomplete:
  • Firestore not enabled
  • Web app not registered
  
To fix:
  • Enable Firestore in Firebase Console
  • Register a web app in Firebase Console
```

Follow each suggestion one by one, then try verification again.

---

# 📊 Understanding Costs

## What's FREE Every Month:

| Service | FREE Tier Limit | Typical Small School Usage |
|---------|----------------|---------------------------|
| Firestore reads | 50,000/day | 10,000-30,000/day ✅ |
| Firestore writes | 20,000/day | 5,000-10,000/day ✅ |
| Storage | 5 GB | 1-3 GB ✅ |
| Authentication | 100,000 ops | 10,000-30,000 ✅ |
| Cloud Messaging | Unlimited | Any amount ✅ |

## Cost Examples:

### Scenario 1: Small School (100 users)
- **Usage**: Well within FREE tier
- **Monthly cost**: **$0.00**

### Scenario 2: Medium School (500 users)
- **Usage**: Slightly over FREE tier (by 10-20%)
- **Monthly cost**: **$2-5**

### Scenario 3: Large School (2000+ users)
- **Usage**: Moderate
- **Monthly cost**: **$10-20**

## How to Monitor Usage:
1. Go to Firebase Console
2. Click **"Usage and billing"** (left menu)
3. View **current month's usage**
4. Compare against FREE tier limits

**Pro tip**: You set up a budget alert at $5, so you'll get an email before any charges!

---

# ❓ Frequently Asked Questions

### Q: Will I really not get charged?
**A**: As long as your usage stays within FREE tier limits (which is typical for small-medium schools), you pay **$0/month**. The budget alert you set up will email you if you approach your limit.

### Q: What if I exceed FREE limits?
**A**: You only pay for usage above free tier. Example: If you use 60,000 Firestore reads (10,000 over free), you pay about **$0.06** (6 cents). The budget alert prevents surprises!

### Q: Can I remove the credit card later?
**A**: Once billing is set up, Firebase requires a payment method to remain active. But with your $5 budget alert, you'll know if you're approaching any charges.

### Q: What if I make a mistake?
**A**: No problem! The app will tell you exactly what's missing and how to fix it. Just follow the suggestions.

### Q: Can multiple schools use the same Firebase project?
**A**: No. Each school MUST have its own Firebase project for:
   - Data isolation (schools can't see each other's data)
   - Security (separate authentication)
   - Cost tracking (each school's usage is separate)

### Q: Who owns the data?
**A**: YOU own the data! It's stored in YOUR Firebase project under YOUR Google account. We don't have access to your school's data.

### Q: Can I delete the project later?
**A**: Yes! Go to Firebase Console → ⚙️ Settings → Scroll down → "Delete project". All data will be permanently deleted.

### Q: Do I need to do this setup for every teacher/student?
**A**: No! Only the school admin does this setup once. Then teachers and students just enter the **School Key** to join.

---

# ✅ Final Checklist

Before using the app, confirm you completed:

- [ ] ✅ Created Firebase project
- [ ] ✅ Wrote down Project ID
- [ ] ✅ Set up billing account (Blaze plan)
- [ ] ✅ Added payment method
- [ ] ✅ Set budget alert at $5
- [ ] ✅ Enabled Firestore Database
- [ ] ✅ Enabled Authentication (Email/Password)
- [ ] ✅ Enabled Cloud Storage
- [ ] ✅ Enabled Cloud Messaging
- [ ] ✅ Registered Web app
- [ ] (Optional) Registered Android app
- [ ] (Optional) Registered iOS app

**All checked?** You're ready to use the app! 🎉

---

# 📞 Need More Help?

### Before contacting support:
1. ✅ Check the error message in the app (it shows exactly what's wrong)
2. ✅ Review the Troubleshooting section above
3. ✅ Try "Verify & Fetch Config" again
4. ✅ Confirm you're signed in with the correct Google account

### When contacting support, include:
- Your Firebase Project ID
- Screenshot of the error message
- Which step you're stuck on
- What you've already tried to fix it

---

# 🎉 Summary

**What you accomplished:**
- ✅ Created a Firebase project for your school
- ✅ Set up billing (with FREE tier and budget alert)
- ✅ Enabled all required services
- ✅ Registered apps (Web + optional Android/iOS)
- ✅ Used our app to automatically fetch API keys
- ✅ Registered your school

**Total time spent:** 5-7 minutes
**Difficulty level:** Easy (with this guide)
**Expected cost:** $0/month (for most schools)
**Success rate:** 100% (if steps followed)

**What's next:**
- Share your **School Key** with teachers and students
- They can join using the key
- Start posting announcements, assignments, and more!

---

**🚀 Congratulations! Your school is now live on the platform!**

*Last updated: October 2025*
