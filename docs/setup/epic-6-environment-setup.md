# Epic 6: Environment Setup Guide

**Complete this BEFORE starting Epic 6 implementation**

---

## ✅ Quick Checklist

- [ ] OpenAI API key obtained
- [ ] `.env` file created in `functions/` directory
- [ ] Production secrets configured
- [ ] Creator UID constant ready
- [ ] `.gitignore` updated

---

## 🔑 Step 1: Get Your OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Sign in or create an account
3. Click **"Create new secret key"**
4. Name it: `buzzbox-production`
5. **IMPORTANT:** Copy the key immediately (starts with `sk-proj-...`)
6. You won't be able to see it again!

**Cost Estimate:**
- Testing (200 messages): ~$2
- Full Epic 6 implementation: $15-25

---

## 📝 Step 2: Create Local `.env` File

```bash
# Navigate to functions directory
cd /Users/andre/coding/buzzbox/functions

# Create .env file
touch .env

# Open in your editor
open .env
```

**Paste this into `.env`:**

```bash
# OpenAI Configuration
OPENAI_API_KEY=sk-proj-YOUR-ACTUAL-KEY-HERE

# Firebase Project ID (find in Firebase Console > Project Settings)
FIREBASE_PROJECT_ID=your-project-id
```

**Replace:**
- `sk-proj-YOUR-ACTUAL-KEY-HERE` → Your actual OpenAI key
- `your-project-id` → Your Firebase project ID

---

## 🔒 Step 3: Configure Production Secrets

**Important:** The `.env` file only works locally. For production deployment, use Firebase Secrets.

```bash
# Set the OpenAI API key as a Firebase secret
firebase functions:secrets:set OPENAI_API_KEY

# When prompted, paste your OpenAI key
# Input: sk-proj-your-actual-key-here
```

**Verify it's set:**

```bash
firebase functions:secrets:access OPENAI_API_KEY
```

---

## 🎯 Step 4: Your Creator UID is Ready

Your Firebase Auth UID has been configured in the PRD:

```typescript
const CREATOR_UID = 'UoLk9GtxDaaYGlI8Ah6RnCbXXbf2';
```

This will be used in Cloud Functions to identify messages sent to you (Andrew).

---

## 🛡️ Step 5: Verify `.gitignore`

Check that `functions/.gitignore` includes:

```bash
# Environment files
.env
.env.local
.env.*.local

# Firebase secrets
.secret.local
```

**If missing, add them now!**

---

## ✅ Step 6: Test Your Setup

```bash
# Start Firebase emulator with your .env
cd /Users/andre/coding/buzzbox
firebase emulators:start --only functions

# You should see:
# ✔ functions: Emulator started at http://localhost:5001
#
# Check logs for "OpenAI client initialized" or similar
```

---

## 📦 Files Created

After completing setup, you should have:

```
buzzbox/
├── functions/
│   ├── .env                    # ✅ LOCAL ONLY - Contains your API key
│   ├── .env.example            # ✅ Safe to commit - Template
│   ├── .gitignore              # ✅ Updated
│   └── package.json            # ✅ Dependencies ready
└── docs/
    └── data/
        └── faqs-preseed.json   # ✅ 15 FAQs ready to paste into Firestore
```

---

## 🚀 You're Ready!

Once you've completed all steps above, you can start **Story 6.1: Firebase Cloud Functions Setup**.

**Next Steps:**
1. `cd functions`
2. `npm install` (if you haven't already)
3. `firebase init functions` (if you haven't already)
4. Follow Epic 6 PRD starting from Story 6.1

---

## 🆘 Troubleshooting

### Error: "OPENAI_API_KEY is not defined"

**Cause:** Environment variable not loaded

**Fix:**
```bash
# Restart emulator
firebase emulators:start --only functions

# For deployed functions, verify secret is set
firebase functions:secrets:access OPENAI_API_KEY
```

### Error: "Invalid API key"

**Cause:** Wrong key or typo

**Fix:**
```bash
# Update the secret
firebase functions:secrets:set OPENAI_API_KEY

# Paste the correct key
```

### Error: "functions.config() is not a function"

**Cause:** Using old Functions v1 API

**Fix:** This should not happen - the PRD has been updated to v2. If you see this, double-check you're using the latest PRD code.

---

## 💰 Cost Monitoring

**Set budget alerts in OpenAI:**
1. Go to https://platform.openai.com/account/billing/limits
2. Set soft limit: $20
3. Set hard limit: $50
4. Enable email notifications

**Check usage:**
- https://platform.openai.com/usage

---

**Questions?** Review Story 6.0 in the Epic 6 PRD for detailed instructions.
