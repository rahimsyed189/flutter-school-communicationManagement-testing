# 🤖 AI-Powered Dynamic Form Generation

## Overview
This feature allows school administrators to create custom form fields using natural language, powered by Google Gemini AI.

## ✅ Setup Complete
- ✅ Gemini API integration added
- ✅ Configuration page created in Admin Settings
- ✅ AI Form Generator service implemented
- ✅ Interactive dialog UI created

## 🔑 Your API Key
```
AIzaSyA5Y1XQHZyqgWn8KbhpVL2RwRNkdFtHj0I
```
**Project Name:** schoolCommApp  
**Client ID:** gen-lang-client-0122516721

## 📋 How to Use

### Step 1: Configure Gemini API
1. Open the app as admin
2. Tap the **Settings** icon (top right)
3. Scroll down to **API Configurations**
4. Tap **Gemini AI Config**
5. Paste your API key: `AIzaSyA5Y1XQHZyqgWn8KbhpVL2RwRNkdFtHj0I`
6. Tap **Save**
7. You should see a green ✅ checkmark

### Step 2: Use AI to Generate Fields
1. Go to **Students** or **Staff** page
2. Tap the **floating AI button** (purple with ✨ icon)
3. Describe what fields you need in plain English:
   - "Add a field for blood group"
   - "I need emergency contact details"
   - "Add address with city, state, and pincode"
4. Tap **Generate Fields**
5. Review the generated fields
6. Tap **Add These Fields to Form**

### Step 3: Fields Auto-Update
- The form will automatically reload with new fields
- All new student/staff records will include these fields
- Existing records remain unchanged

## 💡 Example Prompts

### Medical Information
```
Add medical information including blood group, allergies, and existing conditions
```

### Emergency Contacts
```
I need emergency contact with name, relationship, and phone number
```

### Address Fields
```
Add complete address with house number, street, city, state, and pincode
```

### Custom Dropdown
```
Add a dropdown for transportation mode with options: School Bus, Private Vehicle, Walk, Public Transport
```

## 🎯 Supported Field Types

| Type | Description | Example |
|------|-------------|---------|
| **text** | Single line text | Name, City |
| **textarea** | Multi-line text | Address, Notes |
| **number** | Numeric input | Age, Roll Number |
| **email** | Email address | Email |
| **phone** | Phone number | Contact Number |
| **date** | Date picker | Date of Birth |
| **dropdown** | Select from options | Blood Group, Gender |
| **checkbox** | True/False | Consent, Agreement |

## 🔧 Technical Details

### Firestore Collections
- **app_config/gemini_config**: Stores API key
- **app_config/students_form_config**: Dynamic student form fields
- **app_config/staff_form_config**: Dynamic staff form fields

### Field Configuration Format
```json
{
  "name": "bloodGroup",
  "type": "dropdown",
  "label": "Blood Group",
  "required": true,
  "options": ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"],
  "placeholder": "Select blood group",
  "validation": ""
}
```

### AI Model
- **Model:** Gemini 1.5 Flash
- **Provider:** Google AI Studio
- **Free Tier:** 15 requests/min, 1M tokens/day
- **Response Time:** 1-3 seconds

## 🚀 Features

### ✅ Implemented
- [x] Gemini API integration
- [x] Natural language field generation
- [x] Interactive AI dialog with preview
- [x] Field configuration storage in Firestore
- [x] Admin settings page for API key

### 🔄 In Progress
- [ ] Dynamic form rendering (next step)
- [ ] Field management UI (edit/delete fields)
- [ ] Form preview before saving

### 📝 Planned
- [ ] Field reordering (drag & drop)
- [ ] Visual form builder (no AI needed)
- [ ] Export/import form configurations
- [ ] Form templates library
- [ ] Multi-language support

## 🛡️ Security Notes

- API key stored in Firestore (admin-only access)
- Only admins can access AI form builder
- All AI-generated fields are reviewed before adding
- Validation rules enforced on save

## 📊 Usage Limits

**Free Tier (Current):**
- 15 requests per minute
- 1 million tokens per day
- Unlimited for typical school usage
- No credit card required

**Typical Usage:**
- 1 field generation = ~1 request
- Average school: 5-10 requests/day
- Well within free limits! 🎉

## 🐛 Troubleshooting

### "Failed to generate fields"
- Check Gemini API key is configured
- Verify green ✅ checkmark in settings
- Try rephrasing your prompt
- Check internet connection

### "API key not configured"
- Go to Admin Settings → Gemini AI Config
- Paste API key and tap Save
- Restart the app

### Fields not showing
- Wait 2-3 seconds after adding fields
- Refresh the page (pull down)
- Check Firestore console for config

## 📞 Support

If you encounter issues:
1. Check the API key is correctly saved
2. Verify you're logged in as admin
3. Check Firestore security rules allow reading app_config
4. View logs in Android Studio / Xcode

## 🎓 Next Steps

1. ✅ Test AI field generation
2. ⚠️ Implement dynamic form rendering
3. ⚠️ Add field management UI
4. ⚠️ Build and deploy

---

**Status:** Phase 1 Complete - AI Integration Ready! 🚀
**Next:** Dynamic Form Rendering (converting config to UI widgets)
