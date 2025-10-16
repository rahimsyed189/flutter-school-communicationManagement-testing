# Deploy Billing Plan Detection Fix

## Problem
The app shows "Spark (Free)" plan even though the project has "Blaze (Pay as you go)" plan enabled.

## Root Cause
The Cloud Function code was updated locally but **not deployed to Firebase**. The function running on Firebase is still using old code.

## Solution
Deploy the updated Cloud Function with enhanced billing detection and logging.

## Deployment Steps

### Step 1: Navigate to functions directory
```powershell
cd functions
```

### Step 2: Deploy the updated function
```powershell
firebase deploy --only functions:autoConfigureFirebaseProject
```

### Step 3: Wait for deployment
You should see output like:
```
✔  Deploy complete!

Function URL (autoConfigureFirebaseProject): https://us-central1-YOUR_PROJECT.cloudfunctions.net/autoConfigureFirebaseProject
```

### Step 4: Test with your Blaze plan project
1. Open the app
2. Go to School Registration page
3. Select your project: "newschoo" (or your Blaze plan project)
4. Click "Verify & Configure"
5. **Expected result:**
   - Green SnackBar with "Plan: Blaze (Pay as you go)"
   - Billing status shows "Active ✅"

## What Was Changed

### Enhanced Logging
Added detailed console logs to see:
- Raw billing API response
- Billing check errors (if any)
- Exact values returned by Google Cloud Billing API

### Error Handling
Added `billingCheckError` field in response to show if billing check failed.

### Code Changes (autoConfigureFirebaseProject.js)

**Before:**
```javascript
billingEnabled = billingInfo.data.billingEnabled || false;
```

**After:**
```javascript
console.log('Raw billing API response:', JSON.stringify(billingInfo.data, null, 2));
billingEnabled = billingInfo.data.billingEnabled || false;
billingAccountName = billingInfo.data.billingAccountName || '';
billingPlan = billingEnabled ? 'Blaze (Pay as you go)' : 'Spark (Free)';
console.log('✅ Billing status checked:', { billingEnabled, billingAccountName, billingPlan });
```

## Troubleshooting

### If Still Shows "Spark" After Deployment

**Check Firebase Console Logs:**
1. Go to https://console.firebase.google.com
2. Select your project
3. Go to Functions → Logs
4. Look for the billing API response:
   ```json
   Raw billing API response: {
     "billingEnabled": false,  // This is the problem!
     "billingAccountName": ""
   }
   ```

**Possible Issues:**

#### Issue 1: Wrong Project
- The project "newschoo" might not have billing enabled
- Check if you're selecting the correct project in the dropdown

#### Issue 2: Billing API Permission Error
- The OAuth token might not have billing read permissions
- Look for error: `billingCheckError: "Permission denied"`
- **Solution:** Re-authenticate with Google Sign-In

#### Issue 3: Billing Not Linked to Firebase
- Billing might be enabled on Google Cloud but not linked to Firebase project
- **Solution:**
  1. Go to https://console.firebase.google.com
  2. Select project → Settings → Usage and billing
  3. Ensure "Blaze plan" is shown
  4. If shows "Spark", upgrade to Blaze

## Verification

After deployment, check the app console output:
```
I/flutter: 📡 Response body: {
  "billingEnabled": true,  // ← Should be true for Blaze
  "billingPlan": "Blaze (Pay as you go)",  // ← Should show Blaze
  "billingAccountName": "billingAccounts/XXXXXX-YYYYYY-ZZZZZZ"  // ← Should have account
}
```

## Next Steps

1. **Deploy the function** (see Step 2 above)
2. **Test with app** - Select project and click Verify
3. **Check logs** - Look at Firebase Console → Functions → Logs
4. **Report back** - Share the console output showing billing status

---

**Note:** If the Google Cloud Billing API still returns `billingEnabled: false`, then the project truly doesn't have billing enabled from Google's perspective. In that case, you need to:
1. Check Firebase Console → Settings → Usage and billing
2. Upgrade to Blaze plan if needed
3. Wait 2-3 minutes for changes to propagate
4. Try again

