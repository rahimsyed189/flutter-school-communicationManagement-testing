# ⚠️ Cloud Billing API Not Enabled - Quick Fix

## 🔍 What Your Logs Show

```
"billingCheckError": "Cloud Billing API has not been used in project 402790849608 before or it is disabled..."
```

**Good News:** The Cloud Function IS working! It successfully tried to check billing.
**Problem:** The Cloud Billing API is not enabled in your Firebase project.

## 🚀 Quick Fix (2 minutes)

### **Option 1: Direct Link (Fastest)**

Click this link (replace with your project):
```
https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=402790849608
```

Then click **"ENABLE"** button.

### **Option 2: Manual Steps**

1. **Go to Google Cloud Console:**
   - https://console.cloud.google.com/

2. **Select your Firebase project:**
   - Click project dropdown (top left)
   - Select: **"newschoo"** or **"litt-school-07566"**

3. **Enable Cloud Billing API:**
   - Go to: **APIs & Services** → **Library**
   - Search: **"Cloud Billing API"**
   - Click on it
   - Click **"ENABLE"**

4. **Wait 2-3 minutes** for API to propagate

5. **Test again in your app**

## 📋 Enable for BOTH Projects

You have 2 Firebase projects. Enable the API for BOTH:

### **Project 1: newschoo**
```
Project ID: newschoo
Project Number: 165953698297

Enable at:
https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=newschoo
```

### **Project 2: litt-school-07566**
```
Project ID: litt-school-07566
Project Number: 119188179587

Enable at:
https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=litt-school-07566
```

## ✅ After Enabling

1. **Restart your app** (hot reload won't work, need full restart)
2. Go to **Register School** wizard
3. **Step 2:** Select your project
4. Click **"Verify & Configure"**
5. You should now see:
   - ✅ **Billing Plan: "Blaze (Pay as you go)"** (if you have Blaze)
   - ⚠️ **Billing Plan: "Spark (Free)"** (if you're on free tier)
   - ❌ **NOT "Unknown"** anymore!

## 🔍 How to Verify It's Working

After enabling the API, your logs should show:
```
✅ Billing status checked: { billingEnabled: true, billingPlan: 'Blaze (Pay as you go)' }
```

Instead of the error message.

## 🎯 What's Happening

Your Cloud Function is correctly deployed and working! It's trying to check billing, but Google is blocking it because:
- The **Cloud Billing API** is not enabled in your project
- This is a **one-time setup** - enable it once, works forever
- No code changes needed - just enable the API!

## 💡 Why This Happens

Firebase projects don't automatically enable ALL Google Cloud APIs. You need to manually enable:
- ✅ Firebase Management API (already enabled)
- ✅ Service Usage API (already enabled)
- ❌ **Cloud Billing API (NOT enabled yet)** ← This is the issue!

## 📱 Quick Command (Alternative)

If you have `gcloud` CLI installed:

```bash
# For project "newschoo"
gcloud services enable cloudbilling.googleapis.com --project=newschoo

# For project "litt-school-07566"
gcloud services enable cloudbilling.googleapis.com --project=litt-school-07566
```

## 🎉 Expected Result

After enabling the API, your wizard Step 2 will show:

**For Blaze Plan:**
```
✅ Billing Status
━━━━━━━━━━━━━━━━━━━━
Plan: Blaze (Pay as you go)
Status: Active ✅
Account: billingAccounts/012345-...
```

**For Spark Plan:**
```
⚠️ Billing Status
━━━━━━━━━━━━━━━━━━━━
Plan: Spark (Free)
Status: Not Enabled
Upgrade to Blaze for full features
```

## ⏱️ Time Estimate

- **Enable API:** 30 seconds
- **Wait for propagation:** 2-3 minutes
- **Test in app:** 30 seconds
- **Total:** ~3-4 minutes

---

## 🎯 TL;DR

1. Go to: https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=newschoo
2. Click **"ENABLE"**
3. Wait 2 minutes
4. Test in app - should show billing plan correctly!

**No code changes needed - just enable the API!** 🚀
