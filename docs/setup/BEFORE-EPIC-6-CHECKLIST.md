# ✅ Before Starting Epic 6 - Final Checklist

**Complete these 5 tasks before implementing Epic 6**

---

## 1. ✅ Firebase Functions Initialized

Check if already done:
```bash
ls /Users/andre/coding/buzzbox/functions
```

**Should see:**
- `package.json`
- `src/` or `index.ts`
- `node_modules/`

**If NOT initialized:**
```bash
cd /Users/andre/coding/buzzbox
firebase init functions
# Choose TypeScript
# Choose ESLint: Yes
```

---

## 2. ✅ Install Dependencies

```bash
cd /Users/andre/coding/buzzbox/functions
npm install
```

**Verify packages installed:**
```bash
npm list | grep -E "openai|firebase-functions|firebase-admin"
```

**Should show:**
- `openai@^4.0.0`
- `firebase-functions@^5.0.0`
- `firebase-admin@^12.0.0`

---

## 3. 🔒 Deploy Firestore Security Rules (CRITICAL)

```bash
cd /Users/andre/coding/buzzbox
firebase deploy --only firestore:rules
```

**Verify:**
- Go to Firebase Console > Firestore > Rules
- Check "Published" timestamp is recent

---

## 4. 📝 Create Manual Firestore Data (Before Story 6.3)

### A. Create 15 FAQs

1. Go to Firebase Console > Firestore
2. Create collection: `faqs`
3. Copy FAQs from `/Users/andre/coding/buzzbox/docs/data/faqs-preseed.json`
4. For each FAQ, create document with ID `faq_001`, `faq_002`, etc.
5. Paste fields: `question`, `answer`, `category`, `keywords`, `embedding: null`

**Example:**
```
Collection: faqs
Document ID: faq_001
Fields:
  - question: "What time do you stream?"
  - answer: "I stream Monday-Friday at 7pm EST on YouTube! See you there 🎮"
  - category: "schedule"
  - keywords: ["stream", "streaming", "time", "when", "schedule"]
  - embedding: null
```

### B. Create Creator Profile (Before Story 6.4)

1. Go to Firebase Console > Firestore
2. Create collection: `creator_profiles`
3. Create document with ID: `andrew`
4. Add fields from PRD (Story 6.4, lines 800-833)

**Quick version:**
```
Collection: creator_profiles
Document ID: andrew
Fields:
  - personality: "Friendly tech content creator. Casual but professional."
  - tone: "warm, encouraging, uses emojis occasionally"
  - examples: [array of 5-10 example messages]
  - avoid: ["Overly formal language", "Corporate speak"]
  - signature: "- Andrew"
```

---

## 5. 🔍 Create Firestore Vector Index (CRITICAL - Story 6.3)

**Option A: Firebase Console (Manual)**
1. Firebase Console > Firestore > Indexes
2. Click "Create Index"
3. Collection: `faqs`
4. Field: `embedding`
5. Query scope: Collection
6. **Type: VECTOR** (not Ascending/Descending!)
7. Dimensions: `1536`
8. Distance measure: `COSINE`
9. Click "Create"
10. **WAIT 5-10 minutes for index to build**

**Option B: Firebase CLI (Recommended)**
```bash
# firestore.indexes.json should already exist from PRD
firebase deploy --only firestore:indexes

# Wait 5-10 minutes
# Check status: Firebase Console > Firestore > Indexes
```

---

## ✅ FINAL VERIFICATION

Before starting Story 6.1, verify:

- [ ] Firebase Functions folder exists with `package.json`
- [ ] `npm install` completed successfully
- [ ] OpenAI API key set via `firebase functions:secrets:set OPENAI_API_KEY`
- [ ] Firestore security rules deployed (check timestamp in console)
- [ ] 15 FAQs created in Firestore `faqs` collection
- [ ] Creator profile created in Firestore `creator_profiles/andrew`
- [ ] Firestore vector index created for `faqs.embedding` (Status: Enabled)

---

## 🚀 Ready to Start!

Once all items above are checked:

1. Open `/Users/andre/coding/buzzbox/docs/prd/epic-6-ai-powered-creator-inbox.md`
2. Start with **Story 6.1: Firebase Cloud Functions Setup**
3. Follow Phase 1 → Phase 2 → Phase 3... in order

---

## ❓ Quick Answers

**Q: Do I need to set up emulators?**
A: No! Everything runs directly in production.

**Q: Where's my .env file?**
A: You don't need one. Secrets are set via `firebase functions:secrets:set`

**Q: What's my Creator UID?**
A: `UoLk9GtxDaaYGlI8Ah6RnCbXXbf2` (already configured in PRD code)

**Q: Can I skip the vector index?**
A: NO! FAQ search will fail without it. It's critical.

**Q: How long does the vector index take to build?**
A: 5-10 minutes. Check Firebase Console > Firestore > Indexes for status.

---

**Everything else is already configured in the PRD! Just follow the stories in order.** 🎯
