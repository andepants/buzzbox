# Story 2.0A: Initialize Firebase Cloud Functions

**Epic:** Epic 2 - One-on-One Chat Infrastructure
**Priority:** P0 (BLOCKER - Required for FCM triggers and sequence numbers)
**Estimated Time:** 1 hour
**Story Order:** FIRST story in Epic 2 (before Story 2.0)

---

## Story

**As a developer,**
**I want to initialize Firebase Cloud Functions in the project,**
**so that I can implement server-side triggers for FCM notifications and sequence number assignment.**

---

## Acceptance Criteria

- [ ] Firebase Functions initialized with TypeScript
- [ ] `functions/` directory created with proper structure
- [ ] `firebase.json` updated with Functions configuration
- [ ] Functions dependencies installed (Firebase Functions SDK, Firebase Admin SDK)
- [ ] Functions build system configured (TypeScript compilation)
- [ ] Local emulator setup for Functions testing
- [ ] Functions deployment tested to Firebase project
- [ ] **Three placeholder functions created:** `onMessageCreated`, `assignSequenceNumber`, `updateConversationLastMessage`
- [ ] Functions project configured with correct Firebase project ID
- [ ] Environment variables configured (if needed)

---

## Tasks / Subtasks

- [ ] **Task 1: Initialize Firebase Functions (AC: 1, 2, 3)**
  - [ ] Run `firebase init functions` in project root
  - [ ] Select TypeScript as the language
  - [ ] Install dependencies automatically
  - [ ] Verify `functions/` directory structure created

- [ ] **Task 2: Update firebase.json configuration (AC: 3)**
  - [ ] Add `"functions"` section to `firebase.json`
  - [ ] Configure predeploy build script
  - [ ] Set Node.js version (18+)

- [ ] **Task 3: Install required dependencies (AC: 4)**
  - [ ] Install `firebase-functions` SDK
  - [ ] Install `firebase-admin` SDK
  - [ ] Install TypeScript types for Firebase

- [ ] **Task 4: Configure TypeScript build (AC: 5)**
  - [ ] Verify `tsconfig.json` in `functions/` directory
  - [ ] Test TypeScript compilation with `npm run build`
  - [ ] Verify compiled output in `functions/lib/`

- [ ] **Task 5: Create placeholder Cloud Functions (AC: 8)**
  - [ ] Create `onMessageCreated` function (will trigger on new RTDB message)
  - [ ] Create `assignSequenceNumber` function (will assign atomic sequence numbers)
  - [ ] Create `updateConversationLastMessage` function (will update conversation metadata)
  - [ ] Add TODO comments for future implementation

- [ ] **Task 6: Setup local emulator for testing (AC: 6)**
  - [ ] Run `firebase emulators:start` to verify Functions emulator works
  - [ ] Test function invocation locally
  - [ ] Verify Functions logs appear in emulator UI

- [ ] **Task 7: Deploy to Firebase project (AC: 7)**
  - [ ] Run `firebase deploy --only functions`
  - [ ] Verify functions appear in Firebase Console
  - [ ] Test function invocation in production

---

## Dev Notes

### Firebase Functions Setup Commands

```bash
# 1. Initialize Functions (run from project root)
firebase init functions

# Select the following options:
# - Language: TypeScript
# - Use ESLint: Yes
# - Install dependencies: Yes

# 2. Verify structure created
ls -la functions/
# Expected:
# - src/index.ts
# - package.json
# - tsconfig.json
# - .eslintrc.js

# 3. Install additional dependencies
cd functions
npm install firebase-admin --save
npm install @types/node --save-dev

# 4. Build TypeScript
npm run build

# 5. Test with emulator
firebase emulators:start --only functions

# 6. Deploy to Firebase
firebase deploy --only functions
```

### firebase.json Configuration

Add the following to `firebase.json`:

```json
{
  "database": {
    "rules": "database.rules.json"
  },
  "firestore": {
    "database": "(default)",
    "location": "nam5",
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "runtime": "nodejs18",
    "predeploy": [
      "npm --prefix \"$RESOURCE_DIR\" run lint",
      "npm --prefix \"$RESOURCE_DIR\" run build"
    ]
  }
}
```

### functions/src/index.ts - Placeholder Functions

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Placeholder: Triggered when a new message is created in RTDB
 * Will send FCM notification to message recipients
 *
 * Implementation in Story 2.0B
 */
export const onMessageCreated = functions.database
  .ref("/messages/{conversationID}/{messageID}")
  .onCreate(async (snapshot, context) => {
    // TODO: Implement FCM notification logic in Story 2.0B
    const { conversationID, messageID } = context.params;
    const messageData = snapshot.val();

    console.log(`New message created: ${messageID} in conversation ${conversationID}`);
    console.log("Message data:", messageData);

    return null;
  });

/**
 * Placeholder: Assigns atomic sequence numbers to messages
 * Prevents client-side sequence number manipulation
 *
 * Implementation in Story 2.3
 */
export const assignSequenceNumber = functions.database
  .ref("/messages/{conversationID}/{messageID}")
  .onCreate(async (snapshot, context) => {
    // TODO: Implement sequence number assignment in Story 2.3
    const { conversationID, messageID } = context.params;

    // Get current conversation sequence counter
    const conversationRef = admin.database().ref(`conversations/${conversationID}`);
    const sequenceRef = conversationRef.child("lastSequenceNumber");

    // Atomic increment and assign
    const result = await sequenceRef.transaction((current) => {
      return (current || 0) + 1;
    });

    if (result.committed) {
      // Assign sequence number to message
      await snapshot.ref.update({
        sequenceNumber: result.snapshot.val(),
      });

      console.log(`Assigned sequence number ${result.snapshot.val()} to message ${messageID}`);
    }

    return null;
  });

/**
 * Placeholder: Updates conversation metadata when new message arrives
 * Updates lastMessage, lastMessageTimestamp
 *
 * Implementation in Story 2.3
 */
export const updateConversationLastMessage = functions.database
  .ref("/messages/{conversationID}/{messageID}")
  .onCreate(async (snapshot, context) => {
    // TODO: Implement conversation metadata update in Story 2.3
    const { conversationID, messageID } = context.params;
    const messageData = snapshot.val();

    // Update conversation last message
    const conversationRef = admin.database().ref(`conversations/${conversationID}`);
    await conversationRef.update({
      lastMessage: messageData.text,
      lastMessageTimestamp: admin.database.ServerValue.TIMESTAMP,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
    });

    console.log(`Updated conversation ${conversationID} with latest message`);

    return null;
  });
```

### Directory Structure After Setup

```
project-root/
├── functions/
│   ├── src/
│   │   └── index.ts          # Cloud Functions definitions
│   ├── lib/                  # Compiled JavaScript (generated)
│   ├── package.json
│   ├── tsconfig.json
│   └── .eslintrc.js
├── firebase.json             # Updated with "functions" config
├── database.rules.json
├── firestore.rules
└── sorted/                   # iOS app
```

### Testing

**Local Emulator Testing:**

```bash
# Start emulator
firebase emulators:start

# In another terminal, trigger function manually
curl -X POST http://localhost:5001/sorted-app/us-central1/onMessageCreated \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Production Testing:**

```bash
# Deploy functions
firebase deploy --only functions

# Monitor logs
firebase functions:log

# Test by creating a message in RTDB (via iOS app or Firebase Console)
```

### Environment Variables (if needed)

```bash
# Set Firebase config
firebase functions:config:set someservice.key="THE API KEY"

# View config
firebase functions:config:get
```

---

## Testing

### Test Plan

1. **Initialization Test:**
   - Run `firebase init functions`
   - Verify `functions/` directory created
   - Verify TypeScript compilation works: `cd functions && npm run build`

2. **Configuration Test:**
   - Verify `firebase.json` contains `"functions"` section
   - Check Node.js version set to 18+

3. **Local Emulator Test:**
   - Start emulator: `firebase emulators:start --only functions`
   - Verify Functions Emulator UI accessible at http://localhost:4000
   - Check that placeholder functions appear in emulator

4. **Deployment Test:**
   - Deploy: `firebase deploy --only functions`
   - Open Firebase Console → Functions
   - Verify 3 functions deployed: `onMessageCreated`, `assignSequenceNumber`, `updateConversationLastMessage`

5. **Function Invocation Test:**
   - Create a test message in RTDB (via Firebase Console)
   - Check Functions logs for execution
   - Verify sequence number assigned correctly

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-20 | 1.0 | Initial story creation - Firebase Functions setup | PO (Sarah) |

---

## Notes

**Why This Story Comes First:**

Firebase Cloud Functions are **required infrastructure** for:
1. **Story 2.0B:** FCM notification triggers (send push when message arrives)
2. **Story 2.3:** Atomic sequence number assignment (prevent client manipulation)
3. **Story 2.3:** Server-side conversation metadata updates

Without Functions setup, these features cannot be implemented.

**Placeholder Functions:**

This story creates **placeholder implementations** with TODO comments. The actual business logic will be implemented in later stories:
- `onMessageCreated` → Full implementation in Story 2.0B
- `assignSequenceNumber` → Full implementation in Story 2.3
- `updateConversationLastMessage` → Full implementation in Story 2.3

**Security:**

Functions run with **admin privileges** via Firebase Admin SDK. This allows:
- Reading/writing to RTDB without security rules restrictions
- Sending FCM notifications
- Atomically updating sequence numbers

**Cost:**

Firebase Functions free tier:
- 2M invocations/month
- 400,000 GB-seconds/month
- 200,000 CPU-seconds/month

For MVP, this should be sufficient. Monitor usage in Firebase Console.
