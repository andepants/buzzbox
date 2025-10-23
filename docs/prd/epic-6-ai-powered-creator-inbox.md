# Epic 6: AI-Powered Creator Inbox

**Phase:** Day 3-5 (AI Features Implementation)
**Priority:** P0 (CRITICAL - Worth 30 Points for AI Features + 10 Points for Advanced Capability)
**Estimated Time:** 8 hours
**Epic Owner:** Product Owner
**Dependencies:** Epic 5 (Single-Creator Platform Redesign)

---

## 📋 Strategic Context

### Why This Epic Exists

**Scoring Impact:** This epic delivers **40 points** (40% of total grade):
- **Section 3: AI Features (30 points)** - All 5 required AI features
- **Section 3: Advanced AI Capability (10 points)** - Context-Aware Smart Replies

From scoring rubric (docs/scoring.md):
> **Required AI Features for Content Creator/Influencer (15 points)**
> 1. Auto-categorization (fan/business/spam/urgent)
> 2. Response drafting in creator's voice
> 3. FAQ auto-responder
> 4. Sentiment analysis
> 5. Collaboration opportunity scoring
>
> **Advanced AI Capability (10 points)**
> - Context-Aware Smart Replies: Learns user style accurately, generates authentic-sounding replies, provides 3+ relevant options

**Current State:** After Epic 5, we have a single-creator platform where Andrew receives DMs from fans.

**Problem:** Andrew has no AI assistance to manage fan communication at scale.

**Solution:** Build 5 AI features + Context-Aware Smart Replies using Firebase Cloud Functions + OpenAI.

---

## 🎯 What This Epic Delivers

### User Experience

**For Andrew (The Creator):**
- ✅ **Auto-Categorization:** Every fan DM is automatically labeled (Fan/Business/Spam/Urgent)
- ✅ **Sentiment Analysis:** See emotional tone of messages (Positive/Negative/Urgent/Neutral)
- ✅ **Opportunity Scoring:** Business DMs get scored 0-100 for collaboration potential
- ✅ **FAQ Auto-Responder:** Common questions get instant AI responses
- ✅ **Smart Reply Drafting:** Get 3 AI-generated reply options in Andrew's voice
- ✅ **Context-Aware:** AI uses conversation history to draft relevant, personalized replies

**For Fans:**
- ✅ Instant FAQ responses (if question matches FAQ library)
- ✅ Faster responses from Andrew (AI helps him respond efficiently)

**What's New:**
- 🆕 AI badges on messages (category, sentiment, score)
- 🆕 "Draft Reply" button for Andrew (shows 3 options)
- 🆕 Auto-responses for FAQs
- 🆕 Visual indicators for urgent/business messages
- 🆕 AI settings to control auto-response behavior

---

## 🏗️ Architecture Overview

### Firebase Cloud Functions + OpenAI

```
iOS App → Firebase RTDB → Cloud Functions → OpenAI GPT-4 → RTDB → iOS App
                         ↑
                    Auto-triggered on new messages
```

**Why Cloud Functions Instead of n8n:**
- ✅ Zero cost on Firebase free tier
- ✅ Auto-triggered by RTDB (no webhooks needed)
- ✅ Co-located with Firebase (<1s latency)
- ✅ TypeScript (version controlled, better IDE support)
- ✅ Firebase Emulator Suite for local testing
- ✅ Single stack (no third-party dependencies)

**Trade-offs:**
- ⚠️ Requires Cloud Functions deployment (simple: `firebase deploy --only functions`)
- ⚠️ TypeScript/Node.js knowledge needed (vs visual workflow builder)

---

## 📊 High-Level Implementation Overview

### 1. Firebase Cloud Functions (3 functions)

**Function 1: Auto-Processing (Features 1, 4, 5)**
- **Trigger:** RTDB `onValueWritten('/messages/{conversationId}/{messageId}')`
- **Processing:**
  1. Categorize message (fan/business/spam/urgent) - GPT-3.5
  2. Analyze sentiment (positive/negative/urgent/neutral) - GPT-3.5
  3. Score opportunity (0-100 if business) - GPT-4
- **Output:** Updates message in RTDB with AI metadata
- **Latency:** <1s (parallel processing)
- **iOS:** No code needed - automatic!

**Function 2: FAQ Auto-Responder (Feature 3)**
- **Trigger:** HTTP callable function
- **Processing:**
  1. Embed message with OpenAI embeddings
  2. Vector search Firestore FAQ collection
  3. If confidence >80% → Return FAQ answer
- **Output:** `{ isFAQ: true, answer: "..." }` or `{ isFAQ: false }`
- **Latency:** <2s
- **iOS:** Calls function, auto-sends if FAQ match

**Function 3: Context-Aware Smart Replies (Features 2 + Advanced)**
- **Trigger:** HTTP callable function
- **Processing:**
  1. Fetch last 20 messages from RTDB (conversation context)
  2. Fetch Andrew's writing style from Firestore
  3. Call OpenAI GPT-4 with:
     - System prompt: Andrew's personality/tone
     - Context: Recent conversation history
     - Task: Generate 3 reply options (short/medium/detailed)
- **Output:** `{ drafts: [option1, option2, option3] }`
- **Latency:** <8s (advanced capability target)
- **Satisfies:** "Context-Aware Smart Replies" requirement (10 points)

### 2. iOS Integration

**New Service: `AIService.swift`**
- `checkFAQ()` → Calls Cloud Function 2, auto-responds if match
- `generateSmartReplies()` → Calls Cloud Function 3, displays 3 options
- Note: Auto-processing happens automatically via Cloud Function 1

**UI Updates:**
- AI badges on messages (category, sentiment, score)
- "Draft Reply" button in message composer
- Smart reply selection UI (3 options)
- Auto-response indicator for FAQ answers
- Settings toggle for FAQ auto-response

### 3. Firestore Data Structures

**FAQ Collection (Manual Management):**
```json
{
  "faqs": {
    "faq_001": {
      "question": "What time do you stream?",
      "answer": "I stream Monday-Friday at 7pm EST!",
      "embedding": [...],  // OpenAI embedding
      "category": "schedule"
    }
  }
}
```

**Creator Style Examples:**
```json
{
  "creator_profiles": {
    "andrew": {
      "writing_style": {
        "personality": "Friendly tech content creator...",
        "tone": "warm, encouraging, uses emojis occasionally",
        "examples": [
          "Hey! Thanks for reaching out...",
          "That's awesome! I'd love to...",
          "Appreciate the support, means a lot!"
        ],
        "avoid": ["overly formal", "corporate speak"]
      }
    }
  }
}
```

---

## 📝 User Stories

### Story 6.0: Environment Configuration (15 min)

**As a developer, I want to configure environment variables and constants so Cloud Functions can access OpenAI and identify the creator.**

**Acceptance Criteria:**
- [ ] Creator UID constant defined
- [ ] OpenAI API key configured via environment variable
- [ ] `.env` file created for local development
- [ ] `.env.example` file created for documentation
- [ ] Environment variables accessible in Cloud Functions
- [ ] Production deployment configured with Firebase secrets

**Technical Details:**

**Step 1: Create `.env` file for local development**

Create `functions/.env`:
```bash
# OpenAI API Key (get from https://platform.openai.com/api-keys)
OPENAI_API_KEY=sk-proj-your-key-here

# Firebase Project ID
FIREBASE_PROJECT_ID=your-project-id
```

**Step 2: Create `.env.example` for documentation**

Create `functions/.env.example`:
```bash
# OpenAI API Key - Get from https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-proj-...

# Firebase Project ID - Find in Firebase Console > Project Settings
FIREBASE_PROJECT_ID=your-project-id
```

**Step 3: Add to `.gitignore`**

Ensure `functions/.gitignore` includes:
```
.env
.env.local
```

**Step 4: Configure production secrets (before deployment)**

```bash
# Set OpenAI API key for production
firebase functions:secrets:set OPENAI_API_KEY

# You'll be prompted to enter the key securely
# Paste: sk-proj-your-actual-key-here
```

**Step 5: Verify Firebase Functions dependencies**

Check `functions/package.json` has correct versions:

```json
{
  "scripts": {
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0",
    "openai": "^4.0.0",
    "@google-cloud/firestore": "^7.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "eslint": "^8.0.0"
  }
}
```

**Step 6: Define Creator UID constant**

Creator UID is already configured in all Cloud Functions:
```typescript
// Andrew's Firebase Auth UID (from Firebase Console > Authentication)
const CREATOR_UID = 'UoLk9GtxDaaYGlI8Ah6RnCbXXbf2';
```

**Production Deployment:**

```bash
# Deploy Cloud Functions with secrets
firebase deploy --only functions

# Secrets are automatically available via process.env.OPENAI_API_KEY
```

**Important Notes:**
- Never commit `.env` to git
- Production uses Firebase Secrets via `process.env`
- All development and testing happens in production Firebase
- Check function logs: `firebase functions:log`

**Estimate:** 15 min

---

### Story 6.1: Firebase Cloud Functions Setup (45 min)

**As a developer, I want to set up Firebase Cloud Functions so I can deploy AI workflows.**

**Acceptance Criteria:**
- [ ] Firebase Functions initialized in project (`functions/` directory)
- [ ] OpenAI SDK installed (`npm install openai`)
- [ ] Firebase Admin SDK configured
- [ ] Environment variables configured (OpenAI API key)
- [ ] Test function deployed and working
- [ ] Firebase Emulator Suite set up for local testing

**Technical Details:**

```bash
# Initialize Firebase Functions
cd /Users/andre/coding/buzzbox
firebase init functions
# Choose TypeScript
# Choose ESLint

# Install dependencies
cd functions
npm install openai
npm install @google-cloud/firestore

# Set OpenAI API key
firebase functions:config:set openai.key="sk-..."
```

**Create: `functions/src/index.ts`**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

admin.initializeApp();

const openai = new OpenAI({
  apiKey: functions.config().openai.key,
});

// Test function
export const helloWorld = functions.https.onRequest((request, response) => {
  response.json({ message: "Firebase Functions + OpenAI ready!" });
});
```

**Deploy:**
```bash
firebase deploy --only functions
```

**Test:**
```bash
# Local emulator
firebase emulators:start --only functions
curl http://localhost:5001/[PROJECT-ID]/us-central1/helloWorld
```

**Estimate:** 45 min

---

### Story 6.2: Auto-Processing Cloud Function (Features 1, 4, 5) (2 hours)

**As Andrew, I want every fan DM automatically categorized and analyzed so I can prioritize my responses.**

**Cloud Function Design:**

**Create: `functions/src/ai-processing.ts`**

```typescript
import { onValueWritten } from 'firebase-functions/v2/database';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface Message {
  id: string;
  text: string;
  senderId: string;
  receiverId: string;
  timestamp: number;
}

/**
 * Auto-triggered on new messages to process with AI
 * Features: Categorization (1), Sentiment (4), Opportunity Scoring (5)
 */
export const processMessageAI = onValueWritten({
  ref: '/messages/{conversationId}/{messageId}',
  region: 'us-central1',
}, async (event) => {
    const change = event.data;

    // Only process new messages (not updates)
    if (!change.after.exists()) {
      return null; // Message deleted
    }

    const message = change.after.val() as Message;

    // Only process messages sent to the creator (Andrew)
    const CREATOR_UID = 'UoLk9GtxDaaYGlI8Ah6RnCbXXbf2'; // Andrew's Firebase Auth UID
    if (message.receiverId !== CREATOR_UID) {
      return null;
    }

    // Skip if already processed
    if (change.after.child('aiCategory').exists()) {
      return null;
    }

    try {
      // Parallel AI processing for speed
      const [category, sentiment, score] = await Promise.all([
        categorizeMessage(message.text),
        analyzeSentiment(message.text),
        scoreOpportunity(message.text), // Will return null if not business
      ]);

      // Update message with AI metadata
      await change.after.ref.update({
        aiCategory: category,
        aiSentiment: sentiment,
        aiOpportunityScore: score,
        aiProcessedAt: admin.database.ServerValue.TIMESTAMP,
      });

      logger.info('Processed message', {
        messageId: message.id,
        category,
        sentiment,
        score,
      });

      return { success: true };
    } catch (error) {
      logger.error('AI processing failed', { error });
      // Don't throw - message should still work without AI metadata
      return { success: false, error };
    }
  });

/**
 * Categorize message using GPT-3.5
 */
async function categorizeMessage(text: string): Promise<string> {
  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: 'Categorize this message into ONE category: fan, business, spam, or urgent. Respond with only the category word.',
      },
      {
        role: 'user',
        content: text,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const category = completion.choices[0].message.content?.trim().toLowerCase() || 'fan';

  // Validate category
  if (!['fan', 'business', 'spam', 'urgent'].includes(category)) {
    return 'fan'; // Default fallback
  }

  return category;
}

/**
 * Analyze sentiment using GPT-3.5
 */
async function analyzeSentiment(text: string): Promise<string> {
  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: 'Analyze the sentiment of this message. Choose ONE: positive, negative, urgent, or neutral. Respond with only the sentiment word.',
      },
      {
        role: 'user',
        content: text,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const sentiment = completion.choices[0].message.content?.trim().toLowerCase() || 'neutral';

  // Validate sentiment
  if (!['positive', 'negative', 'urgent', 'neutral'].includes(sentiment)) {
    return 'neutral';
  }

  return sentiment;
}

/**
 * Score business opportunities using GPT-4
 * Only called after categorization confirms it's a business message
 */
async function scoreOpportunity(text: string): Promise<number | null> {
  // First do a quick categorization to see if it's business
  const category = await categorizeMessage(text);

  if (category !== 'business') {
    return null; // Not a business message
  }

  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      {
        role: 'system',
        content: `Score this business collaboration opportunity from 0-100 based on:
- Monetary value potential
- Brand fit for a tech content creator
- Legitimacy (not spam)
- Urgency

Respond with only a number from 0-100.`,
      },
      {
        role: 'user',
        content: text,
      },
    ],
    temperature: 0.5,
    max_tokens: 10,
  });

  const scoreText = completion.choices[0].message.content?.trim() || '50';
  const score = parseInt(scoreText, 10);

  // Validate score
  if (isNaN(score) || score < 0 || score > 100) {
    return 50; // Default middle score
  }

  return score;
}
```

**Update: `functions/src/index.ts`**
```typescript
export { processMessageAI } from './ai-processing';
```

**iOS Integration:**

No code changes needed! Messages automatically get AI metadata when written to RTDB.

**Update: `MessageBubbleView.swift`** (to display AI metadata)
```swift
struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Message bubble
            Text(message.text)
                .padding()
                .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(16)

            // AI Metadata (only show for creator viewing fan messages)
            if !isFromCurrentUser,
               let category = message.aiCategory {
                AIMetadataBadgeView(
                    category: category,
                    sentiment: message.aiSentiment,
                    score: message.aiOpportunityScore
                )
            }

            // Timestamp
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
    }
}
```

**Acceptance Criteria:**
- [ ] Cloud Function deploys successfully
- [ ] Auto-triggers on new RTDB messages
- [ ] Categorization returns valid category (fan/business/spam/urgent)
- [ ] Sentiment analysis returns valid sentiment (positive/negative/urgent/neutral)
- [ ] Opportunity scoring only runs for business messages
- [ ] All 3 AI features run in parallel (<1s total)
- [ ] Message metadata saved to RTDB
- [ ] iOS displays AI badges correctly
- [ ] Works for all message types
- [ ] Errors don't break message sending (graceful degradation)

**Estimate:** 2 hours

---

### Story 6.3: FAQ Auto-Responder Cloud Function (Feature 3) (1.5 hours)

**As a fan, I want instant answers to common questions so I don't have to wait for Andrew.**

**FAQ Library Setup (Manual):**

Create 10-15 FAQs in Firestore manually via Firebase Console:

```json
{
  "faqs": {
    "faq_001": {
      "question": "What time do you stream?",
      "answer": "I stream Monday-Friday at 7pm EST on YouTube! See you there 🎮",
      "category": "schedule",
      "keywords": ["stream", "streaming", "time", "when", "schedule"],
      "embedding": null  // Will be generated by Cloud Function
    },
    "faq_002": {
      "question": "How can I support you?",
      "answer": "Thanks for asking! You can support through YouTube memberships, Patreon, or just sharing my content. Every bit helps! 🙏",
      "category": "support",
      "keywords": ["support", "patreon", "membership", "donate"],
      "embedding": null
    }
  }
}
```

**Firestore Vector Index Setup (REQUIRED):**

Before FAQ search will work, you must create a vector index:

**Option 1: Firebase Console (Manual)**
1. Go to Firebase Console > Firestore > Indexes
2. Click "Create Index"
3. Collection: `faqs`
4. Field: `embedding`
5. Type: **Vector** (not regular index!)
6. Dimensions: **1536** (for text-embedding-3-small)
7. Distance Measure: **COSINE**

**Option 2: Firebase CLI (Recommended)**

Create `firestore.indexes.json`:
```json
{
  "indexes": [],
  "fieldOverrides": [
    {
      "collectionGroup": "faqs",
      "fieldPath": "embedding",
      "indexes": [
        {
          "order": "ASCENDING",
          "queryScope": "COLLECTION"
        }
      ],
      "vectorConfig": {
        "dimension": 1536,
        "flat": {}
      }
    }
  ]
}
```

Deploy the index:
```bash
firebase deploy --only firestore:indexes
# Wait 5-10 minutes for index to build
# Check status: Firebase Console > Firestore > Indexes
```

**Cloud Function Design:**

**Create: `functions/src/faq.ts`**

```typescript
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { FieldValue } from '@google-cloud/firestore';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface FAQ {
  question: string;
  answer: string;
  category: string;
  keywords: string[];
  embedding: number[];
}

interface FAQResponse {
  isFAQ: boolean;
  answer?: string;
  confidence?: number;
  matchedQuestion?: string;
}

/**
 * Check if message matches FAQ using Firestore native vector search
 * Feature 3: FAQ Auto-Responder
 */
export const checkFAQ = functions.https.onCall(async (request) => {
  const { text } = request.data;

  if (!text || typeof text !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Text is required');
  }

  try {
    // 1. Generate embedding for user's message
    const embeddingResponse = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: text,
    });

    const messageEmbedding = embeddingResponse.data[0].embedding;

    // 2. Use Firestore native vector search
    const vectorQuery = admin.firestore()
      .collection('faqs')
      .findNearest({
        vectorField: 'embedding',
        queryVector: FieldValue.vector(messageEmbedding),
        limit: 5,
        distanceMeasure: 'COSINE',
        distanceResultField: 'distance'
      });

    const results = await vectorQuery.get();

    if (results.empty) {
      return { isFAQ: false } as FAQResponse;
    }

    // 3. Get best match
    const bestMatch = results.docs[0];
    const faqData = bestMatch.data() as FAQ;
    const distance = (bestMatch as any).distance; // Cosine distance (0 = identical, 2 = opposite)

    // Convert distance to similarity (0-1 range)
    const similarity = 1 - (distance / 2);

    functions.logger.info('FAQ match found', {
      question: faqData.question,
      similarity,
      distance
    });

    // 4. Return if confidence > 80%
    if (similarity > 0.80) {
      return {
        isFAQ: true,
        answer: faqData.answer,
        confidence: similarity,
        matchedQuestion: faqData.question
      } as FAQResponse;
    }

    return { isFAQ: false } as FAQResponse;

  } catch (error) {
    functions.logger.error('FAQ check failed:', error);
    throw new functions.https.HttpsError('internal', 'FAQ check failed');
  }
});

/**
 * Generate embeddings for all FAQs using OpenAI
 * Run this once after creating FAQs manually
 */
export const generateFAQEmbeddings = functions.https.onRequest(async (req, res) => {
  try {
    const faqsSnapshot = await admin.firestore()
      .collection('faqs')
      .get();

    const updates: Promise<any>[] = [];

    for (const doc of faqsSnapshot.docs) {
      const faq = doc.data() as FAQ;

      // Skip if already has embedding
      if (faq.embedding && faq.embedding.length > 0) {
        continue;
      }

      // Generate embedding from question
      const embeddingResponse = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: faq.question,
      });

      const embedding = embeddingResponse.data[0].embedding;

      // Update Firestore with FieldValue.vector()
      updates.push(
        doc.ref.update({
          embedding: FieldValue.vector(embedding)
        })
      );

      functions.logger.info('Generated embedding for FAQ', {
        id: doc.id,
        question: faq.question
      });
    }

    await Promise.all(updates);

    res.json({
      success: true,
      count: updates.length,
      message: 'FAQ embeddings generated successfully'
    });

  } catch (error) {
    functions.logger.error('Embedding generation failed:', error);
    res.status(500).json({ error: 'Embedding generation failed' });
  }
});
```

**Update: `functions/src/index.ts`**
```typescript
export { checkFAQ, generateFAQEmbeddings } from './faq';
```

**One-Time Setup (Generate Embeddings):**
```bash
# After deploying, call this once to generate embeddings
curl https://us-central1-[PROJECT-ID].cloudfunctions.net/generateFAQEmbeddings
```

**iOS Integration:**

**Update: `AIService.swift`**
```swift
import FirebaseFunctions

@MainActor
final class AIService: ObservableObject {
    private let functions = Functions.functions()

    struct FAQResponse: Codable {
        let isFAQ: Bool
        let answer: String?
        let confidence: Double?
        let matchedQuestion: String?
    }

    func checkFAQ(_ text: String) async throws -> FAQResponse {
        let result = try await functions.httpsCallable("checkFAQ")
            .call(["text": text])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(FAQResponse.self, from: data)
    }
}
```

**Update: `MessageThreadViewModel.swift`**
```swift
func receiveMessage(_ message: MessageEntity) async {
    // 1. Display message in UI
    messages.append(message)

    // 2. Check if FAQ (only for fan messages to creator)
    if message.receiverId == CREATOR_ID {
        do {
            let faqResponse = try await aiService.checkFAQ(message.text)

            if faqResponse.isFAQ, let answer = faqResponse.answer {
                // 3. Auto-send FAQ response
                await sendMessage(answer, isAIGenerated: true)

                // Log for analytics
                print("📚 FAQ matched: \(faqResponse.matchedQuestion ?? "")")
                print("✨ Confidence: \(faqResponse.confidence ?? 0)")
            }
        } catch {
            // Silent fail - don't block on FAQ check
            print("FAQ check failed: \(error)")
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Firestore vector index created for `faqs.embedding` field (1536 dimensions, COSINE)
- [ ] Index status shows "Enabled" in Firebase Console
- [ ] 10-15 FAQs created in Firestore manually with keywords
- [ ] `generateFAQEmbeddings` function generates embeddings successfully
- [ ] FAQs stored with FieldValue.vector() format
- [ ] `checkFAQ` function uses native Firestore vector search (findNearest)
- [ ] Confidence threshold >80% for auto-response
- [ ] iOS receives matchedQuestion in response
- [ ] iOS auto-sends FAQ answers
- [ ] AI-generated badge shows on auto-responses
- [ ] FAQ check failures don't block message delivery

**Estimate:** 1.5 hours

---

### Story 6.4: Context-Aware Smart Replies Cloud Function (Feature 2 + Advanced) (2 hours)

**As Andrew, I want AI to draft replies in my voice with conversation context so I can respond faster and more authentically.**

**This satisfies TWO requirements:**
- Feature 2: Response drafting in creator's voice
- Advanced AI Capability: Context-Aware Smart Replies (10 points)

**Creator Profile Setup (Manual):**

Create creator profile in Firestore manually via Firebase Console:

```json
{
  "creator_profiles": {
    "andrew": {
      "personality": "Friendly tech content creator. Casual but professional. Authentic and enthusiastic about helping fans.",
      "tone": "warm, encouraging, uses emojis occasionally",
      "examples": [
        "Hey! Thanks so much for reaching out! 🙌",
        "That's awesome! I'd love to hear more about your project.",
        "Appreciate the kind words, it really means a lot!",
        "Great question! Here's how I approach that...",
        "Let me know if you need anything else, always happy to help!"
      ],
      "avoid": [
        "Overly formal language",
        "Corporate speak",
        "Robotic responses",
        "Generic templates"
      ],
      "signature": "- Andrew"
    }
  }
}
```

**Cloud Function Design:**

**Create: `functions/src/smart-replies.ts`**

```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface Message {
  senderName: string;
  text: string;
  timestamp: number;
}

interface CreatorProfile {
  personality: string;
  tone: string;
  examples: string[];
  avoid: string[];
  signature?: string;
}

interface SmartReplyResponse {
  drafts: {
    short: string;
    medium: string;
    detailed: string;
  };
}

interface SmartReplyRequest {
  conversationId: string;
  messageText: string;
}

/**
 * Generate 3 context-aware smart replies in creator's voice
 * Features: Response Drafting (2) + Advanced AI Capability
 */
export const generateSmartReplies = onCall<SmartReplyRequest>({
  region: 'us-central1',
}, async (request) => {
  const { conversationId, messageText } = request.data;

  if (!conversationId || !messageText) {
    throw new HttpsError(
      'invalid-argument',
      'conversationId and messageText are required'
    );
  }

  try {
    // Fetch recent messages from RTDB (last 20)
    const messagesSnapshot = await admin.database()
      .ref(`/messages/${conversationId}`)
      .orderByChild('timestamp')
      .limitToLast(20)
      .once('value');

    const messages: Message[] = [];
    messagesSnapshot.forEach((child) => {
      messages.push(child.val() as Message);
    });

    // Fetch creator profile from Firestore
    const profileDoc = await admin.firestore()
      .collection('creator_profiles')
      .doc('andrew')
      .get();

    if (!profileDoc.exists) {
      throw new HttpsError('not-found', 'Creator profile not found');
    }

    const profile = profileDoc.data() as CreatorProfile;

    // Build context prompt
    const conversationContext = messages
      .map((m) => `${m.senderName}: ${m.text}`)
      .join('\n');

    const systemPrompt = `You are Andrew, a ${profile.personality}

Your tone: ${profile.tone}

Example responses you've written:
${profile.examples.join('\n')}

Avoid: ${profile.avoid.join(', ')}

Recent conversation context:
${conversationContext}`;

    const userPrompt = `The fan just sent: "${messageText}"

Generate 3 reply options:
1. Short (1 sentence, quick acknowledgment)
2. Medium (2-3 sentences, friendly and helpful)
3. Detailed (4-5 sentences, comprehensive response)

Make each option sound authentic to Andrew's voice. Use conversation context to make replies relevant.

Respond with ONLY valid JSON in this exact format:
{
  "short": "your short reply here",
  "medium": "your medium reply here",
  "detailed": "your detailed reply here"
}`;

    // Call OpenAI GPT-4
    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      response_format: { type: 'json_object' },
    });

    const responseText = completion.choices[0].message.content;

    if (!responseText) {
      throw new Error('No response from OpenAI');
    }

    const drafts = JSON.parse(responseText);

    return {
      drafts: {
        short: drafts.short || '',
        medium: drafts.medium || '',
        detailed: drafts.detailed || '',
      },
    } as SmartReplyResponse;

  } catch (error) {
    logger.error('Smart reply generation failed', { error });
    throw new HttpsError('internal', 'Smart reply generation failed');
  }
});
```

**Update: `functions/src/index.ts`**
```typescript
export { generateSmartReplies } from './smart-replies';
```

**iOS Integration:**

**Update: `AIService.swift`**
```swift
struct SmartReplyResponse: Codable {
    struct Drafts: Codable {
        let short: String
        let medium: String
        let detailed: String
    }
    let drafts: Drafts
}

func generateSmartReplies(
    conversationId: String,
    messageText: String
) async throws -> [String] {
    let result = try await functions.httpsCallable("generateSmartReplies")
        .call([
            "conversationId": conversationId,
            "messageText": messageText
        ])

    let data = try JSONSerialization.data(withJSONObject: result.data)
    let response = try JSONDecoder().decode(SmartReplyResponse.self, from: data)

    return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
}
```

**Create: `buzzbox/Core/Views/Components/SmartReplyPickerView.swift`**
```swift
import SwiftUI

struct SmartReplyPickerView: View {
    let drafts: [String]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("✨ AI-Generated Replies")
                .font(.headline)

            ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                Button {
                    onSelect(draft)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(draftLabel(index))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(draft.count) chars")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(draft)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Button("Dismiss", action: onDismiss)
                .font(.footnote)
        }
        .padding()
    }

    func draftLabel(_ index: Int) -> String {
        ["📝 Short", "💬 Medium", "📄 Detailed"][index]
    }
}
```

**Update: `MessageThreadView.swift`**
```swift
struct MessageThreadView: View {
    @StateObject private var viewModel: MessageThreadViewModel
    @EnvironmentObject private var aiService: AIService

    @State private var showSmartReplies = false
    @State private var smartReplyDrafts: [String] = []
    @State private var isLoadingDrafts = false
    @State private var messageText = ""

    var body: some View {
        VStack {
            messageListView

            HStack {
                if viewModel.isCreator {
                    Button {
                        Task {
                            isLoadingDrafts = true
                            do {
                                smartReplyDrafts = try await aiService.generateSmartReplies(
                                    conversationId: viewModel.conversationId,
                                    messageText: viewModel.lastMessage?.text ?? ""
                                )
                                showSmartReplies = true
                            } catch {
                                // Show error toast
                                print("Failed to generate drafts: \(error)")
                            }
                            isLoadingDrafts = false
                        }
                    } label: {
                        if isLoadingDrafts {
                            ProgressView()
                        } else {
                            Label("Draft Reply", systemImage: "sparkles")
                        }
                    }
                    .disabled(isLoadingDrafts)
                }

                messageComposer
            }
        }
        .sheet(isPresented: $showSmartReplies) {
            SmartReplyPickerView(
                drafts: smartReplyDrafts,
                onSelect: { draft in
                    messageText = draft  // Populate composer
                    showSmartReplies = false
                },
                onDismiss: { showSmartReplies = false }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Cloud Function fetches conversation context (last 20 messages)
- [ ] Creator profile with style examples stored in Firestore
- [ ] GPT-4 generates 3 distinct reply options
- [ ] iOS shows smart reply picker with 3 options
- [ ] Selecting a draft populates message composer (editable)
- [ ] Response time <8s (meets rubric target)
- [ ] Drafts sound authentic to Andrew's voice
- [ ] Drafts use conversation context (not generic)
- [ ] Loading state shows while generating
- [ ] Error handling with user-friendly messages

**Advanced AI Capability Requirements Met:**
- ✅ Learns user style accurately (from examples + profile)
- ✅ Generates authentic-sounding replies (GPT-4 with style training)
- ✅ Provides 3+ relevant options (short/medium/detailed)
- ✅ Response times meet targets (<8s)
- ✅ Context-aware (uses recent messages)

**Estimate:** 2 hours

---

### Story 6.5: iOS AI Service Integration (30 min)

**As a developer, I want a clean AIService layer so all AI features are centralized and testable.**

**Create: `buzzbox/Core/Services/AIService.swift`**

```swift
import Foundation
import FirebaseFunctions

/// AI service for Firebase Cloud Functions integration
/// Handles FAQ auto-responder and smart reply generation
/// Note: Auto-processing (categorization, sentiment, scoring) happens automatically via Cloud Function triggers
@MainActor
final class AIService: ObservableObject {

    // MARK: - Configuration

    private let functions = Functions.functions()

    // MARK: - FAQ Auto-Responder (Feature 3)

    struct FAQResponse: Codable {
        let isFAQ: Bool
        let answer: String?
        let confidence: Double?
    }

    /// Check if message matches FAQ and return auto-response
    func checkFAQ(_ text: String) async throws -> FAQResponse {
        let result = try await functions.httpsCallable("checkFAQ")
            .call(["text": text])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(FAQResponse.self, from: data)
    }

    // MARK: - Context-Aware Smart Replies (Feature 2 + Advanced)

    struct SmartReplyResponse: Codable {
        struct Drafts: Codable {
            let short: String
            let medium: String
            let detailed: String
        }
        let drafts: Drafts
    }

    /// Generate 3 context-aware smart replies in creator's voice
    func generateSmartReplies(
        conversationId: String,
        messageText: String
    ) async throws -> [String] {
        let result = try await functions.httpsCallable("generateSmartReplies")
            .call([
                "conversationId": conversationId,
                "messageText": messageText
            ])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        let response = try JSONDecoder().decode(SmartReplyResponse.self, from: data)

        return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
    }
}
```

**Inject into App:**

```swift
// In buzzboxApp.swift
@main
struct buzzboxApp: App {
    @StateObject private var aiService = AIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(aiService)
        }
    }
}
```

**Acceptance Criteria:**
- [ ] AIService created with FAQ and Smart Replies features
- [ ] Clean async/await API
- [ ] Uses Firebase Functions SDK (not direct HTTP)
- [ ] Injectable via @EnvironmentObject for testing
- [ ] Proper error handling (throws)
- [ ] No hardcoded URLs (uses Firebase SDK)

**Estimate:** 30 min

---

### Story 6.6: Message Model Updates for AI Metadata (45 min)

**As a developer, I want to store AI metadata on messages so the UI can display categories, sentiment, and scores.**

**Update: `buzzbox/Core/Models/MessageEntity.swift`**

```swift
import SwiftData
import Foundation

@Model
final class MessageEntity {
    // EXISTING FIELDS (keep all)
    var id: String
    var conversationID: String
    var senderID: String
    var text: String
    var timestamp: Date
    var status: MessageStatus
    var readBy: [String]

    // NEW: AI Metadata Fields
    var aiCategory: String?           // "fan" | "business" | "spam" | "urgent"
    var aiSentiment: String?          // "positive" | "negative" | "urgent" | "neutral"
    var aiOpportunityScore: Int?      // 0-100 (only for business)
    var isAIGenerated: Bool           // True if FAQ auto-response
    var aiProcessedAt: Date?          // When AI processing completed

    init(
        id: String = UUID().uuidString,
        conversationID: String,
        senderID: String,
        text: String,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        readBy: [String] = [],
        // AI metadata (optional)
        aiCategory: String? = nil,
        aiSentiment: String? = nil,
        aiOpportunityScore: Int? = nil,
        isAIGenerated: Bool = false,
        aiProcessedAt: Date? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.aiCategory = aiCategory
        self.aiSentiment = aiSentiment
        self.aiOpportunityScore = aiOpportunityScore
        self.isAIGenerated = isAIGenerated
        self.aiProcessedAt = aiProcessedAt
    }
}
```

**Update RTDB Sync (RealtimeDBService):**

**Update: `buzzbox/Core/Services/RealtimeDBService.swift`**

```swift
/// Sync message to RTDB with AI metadata
func syncMessage(_ message: MessageEntity) async throws {
    let messageRef = database.child("messages")
        .child(message.conversationID)
        .child(message.id)

    var data: [String: Any] = [
        "id": message.id,
        "text": message.text,
        "senderID": message.senderID,
        "timestamp": ServerValue.timestamp(),
        "status": message.status.rawValue,
        "readBy": message.readBy,
    ]

    // AI Metadata (optional fields)
    if let aiCategory = message.aiCategory {
        data["aiCategory"] = aiCategory
    }
    if let aiSentiment = message.aiSentiment {
        data["aiSentiment"] = aiSentiment
    }
    if let aiOpportunityScore = message.aiOpportunityScore {
        data["aiOpportunityScore"] = aiOpportunityScore
    }
    data["isAIGenerated"] = message.isAIGenerated
    if let aiProcessedAt = message.aiProcessedAt {
        data["aiProcessedAt"] = aiProcessedAt.timeIntervalSince1970
    }

    try await messageRef.setValue(data)
}

/// Listen for AI metadata updates from Cloud Functions
func observeMessageUpdates(conversationId: String, handler: @escaping (MessageEntity) -> Void) {
    let messagesRef = database.child("messages").child(conversationId)

    messagesRef.observe(.childChanged) { snapshot in
        guard let dict = snapshot.value as? [String: Any] else { return }

        // Parse AI metadata
        let message = MessageEntity(
            id: dict["id"] as? String ?? "",
            conversationID: conversationId,
            senderID: dict["senderID"] as? String ?? "",
            text: dict["text"] as? String ?? "",
            timestamp: Date(timeIntervalSince1970: dict["timestamp"] as? TimeInterval ?? 0),
            status: MessageStatus(rawValue: dict["status"] as? String ?? "sent") ?? .sent,
            readBy: dict["readBy"] as? [String] ?? [],
            aiCategory: dict["aiCategory"] as? String,
            aiSentiment: dict["aiSentiment"] as? String,
            aiOpportunityScore: dict["aiOpportunityScore"] as? Int,
            isAIGenerated: dict["isAIGenerated"] as? Bool ?? false,
            aiProcessedAt: (dict["aiProcessedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        )

        handler(message)
    }
}
```

**SwiftData Migration:**

SwiftData handles schema changes automatically when adding optional fields. Existing messages will have `nil` for AI metadata.

**Acceptance Criteria:**
- [ ] AI fields added to MessageEntity (all optional except `isAIGenerated`)
- [ ] SwiftData migration handled automatically (optional fields)
- [ ] RTDB sync includes AI metadata
- [ ] RTDB observer updates messages when AI metadata arrives
- [ ] Backward compatible with existing messages (nil values)
- [ ] Cloud Function updates propagate to iOS automatically

**Estimate:** 45 min

---

### Story 6.7: AI UI Components (1.5 hours)

**As Andrew, I want to see AI insights visually so I can quickly triage messages.**

**Create: `buzzbox/Core/Views/Components/AIMetadataBadgeView.swift`**

```swift
import SwiftUI

struct AIMetadataBadgeView: View {
    let category: String?
    let sentiment: String?
    let score: Int?

    var body: some View {
        HStack(spacing: 8) {
            if let category {
                categoryBadge(category)
            }

            if let sentiment {
                sentimentBadge(sentiment)
            }

            if let score, category == "business" {
                scoreBadge(score)
            }
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func categoryBadge(_ category: String) -> some View {
        Label {
            Text(category.capitalized)
        } icon: {
            Image(systemName: categoryIcon(category))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(categoryColor(category).opacity(0.2))
        .foregroundStyle(categoryColor(category))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func sentimentBadge(_ sentiment: String) -> some View {
        Circle()
            .fill(sentimentColor(sentiment))
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(sentimentColor(sentiment).opacity(0.3), lineWidth: 2)
            }
    }

    @ViewBuilder
    private func scoreBadge(_ score: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
            Text("\(score)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(scoreColor(score).opacity(0.2))
        .foregroundStyle(scoreColor(score))
        .cornerRadius(8)
    }

    // MARK: - Styling Helpers

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "fan": return "heart.fill"
        case "business": return "briefcase.fill"
        case "spam": return "trash.fill"
        case "urgent": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "fan": return .blue
        case "business": return .purple
        case "spam": return .gray
        case "urgent": return .red
        default: return .secondary
        }
    }

    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment {
        case "positive": return .green
        case "negative": return .red
        case "urgent": return .orange
        case "neutral": return .gray
        default: return .secondary
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}
```

**Update: `MessageBubbleView.swift`**

```swift
struct MessageBubbleView: View {
    let message: MessageEntity
    let isFromCurrentUser: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Message bubble
            Text(message.text)
                .padding()
                .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(16)

            // AI Metadata (only show for creator viewing fan messages)
            if !isFromCurrentUser {
                AIMetadataBadgeView(
                    category: message.aiCategory,
                    sentiment: message.aiSentiment,
                    score: message.aiOpportunityScore
                )
            }

            // AI-generated indicator
            if message.isAIGenerated {
                Label("AI Response", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Timestamp
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
    }
}
```

**Acceptance Criteria:**
- [ ] AI badges show category, sentiment, score
- [ ] Color-coded for quick visual scanning
- [ ] Icons match category type
- [ ] AI-generated badge for FAQ responses
- [ ] Only shows on creator's view of fan messages
- [ ] Looks good in light and dark mode
- [ ] Animates in when AI metadata arrives

**Estimate:** 1.5 hours

---

### Story 6.8: Error Handling & Degraded Mode (1 hour)

**As a user, I want messages to work even when AI features fail so the core messaging experience is reliable.**

**Update: `functions/src/ai-processing.ts`**

```typescript
export const processMessageAI = functions.database
  .ref('/messages/{conversationId}/{messageId}')
  .onWrite(async (change, context) => {
    // Only process new messages (not updates)
    if (!change.after.exists()) {
      return null;
    }

    const message = change.after.val() as Message;

    // Only process messages sent to creator
    const CREATOR_ID = 'andrew_creator_id';
    if (message.receiverId !== CREATOR_ID) {
      return null;
    }

    // Skip if already processed
    if (change.after.child('aiCategory').exists()) {
      return null;
    }

    try {
      // Parallel processing with timeout
      const timeout = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('AI processing timeout')), 5000)
      );

      const processing = Promise.all([
        categorizeMessage(message.text),
        analyzeSentiment(message.text),
        scoreOpportunity(message.text),
      ]);

      const [category, sentiment, score] = await Promise.race([
        processing,
        timeout,
      ]) as [string, string, number | null];

      // Update with AI metadata
      await change.after.ref.update({
        aiCategory: category,
        aiSentiment: sentiment,
        aiOpportunityScore: score,
        aiProcessedAt: admin.database.ServerValue.TIMESTAMP,
      });

      return { success: true };

    } catch (error) {
      // Log error but don't fail
      functions.logger.error('AI processing failed:', error);

      // Mark as failed so we don't retry
      await change.after.ref.update({
        aiProcessingFailed: true,
        aiProcessedAt: admin.database.ServerValue.TIMESTAMP,
      });

      return { success: false, error: String(error) };
    }
  });
```

**Update: `AIService.swift`**

```swift
func checkFAQ(_ text: String) async throws -> FAQResponse {
    do {
        let result = try await functions.httpsCallable("checkFAQ")
            .call(["text": text])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(FAQResponse.self, from: data)
    } catch {
        // Log error but don't throw - return non-FAQ response
        print("FAQ check failed: \(error)")
        return FAQResponse(isFAQ: false, answer: nil, confidence: nil)
    }
}

func generateSmartReplies(
    conversationId: String,
    messageText: String
) async throws -> [String] {
    do {
        let result = try await functions.httpsCallable("generateSmartReplies")
            .call([
                "conversationId": conversationId,
                "messageText": messageText
            ])

        let data = try JSONSerialization.data(withJSONObject: result.data)
        let response = try JSONDecoder().decode(SmartReplyResponse.self, from: data)

        return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
    } catch {
        // Re-throw for smart replies - user initiated action should show error
        throw AIServiceError.smartReplyFailed(error)
    }
}

enum AIServiceError: LocalizedError {
    case smartReplyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .smartReplyFailed:
            return "Failed to generate smart replies. Please try again."
        }
    }
}
```

**Update: `MessageThreadView.swift`**

```swift
Button {
    Task {
        isLoadingDrafts = true
        do {
            smartReplyDrafts = try await aiService.generateSmartReplies(
                conversationId: viewModel.conversationId,
                messageText: viewModel.lastMessage?.text ?? ""
            )
            showSmartReplies = true
        } catch {
            // Show error toast
            errorMessage = "Failed to generate AI replies. Please try again."
            showError = true
        }
        isLoadingDrafts = false
    }
} label: {
    if isLoadingDrafts {
        ProgressView()
    } else {
        Label("Draft Reply", systemImage: "sparkles")
    }
}
.disabled(isLoadingDrafts)
.alert("Error", isPresented: $showError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(errorMessage)
}
```

**Acceptance Criteria:**
- [ ] Messages send/receive even if Cloud Functions are down
- [ ] Auto-processing has 5s timeout
- [ ] Failed AI processing doesn't retry indefinitely
- [ ] FAQ check failures return `isFAQ: false` (silent fail)
- [ ] Smart reply failures show user-friendly error
- [ ] Error logs in Firebase Console for debugging
- [ ] Degraded mode clearly visible (no AI badges)

**Estimate:** 1 hour

---

### Story 6.9: AI Settings UI (30 min)

**As Andrew, I want to control AI behavior so I can disable features I don't want.**

**Create: `buzzbox/Core/Views/Settings/AISettingsView.swift`**

```swift
import SwiftUI

struct AISettingsView: View {
    @AppStorage("ai.faqAutoResponse.enabled") private var faqAutoResponseEnabled = true
    @AppStorage("ai.autoProcessing.enabled") private var autoProcessingEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("FAQ Auto-Response", isOn: $faqAutoResponseEnabled)
                Text("Automatically send FAQ answers when fans ask common questions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Auto-Response")
            }

            Section {
                Toggle("Auto-Categorization", isOn: $autoProcessingEnabled)
                Text("Automatically analyze messages with AI (categorization, sentiment, scoring)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("AI Processing")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Replies")
                        .font(.headline)
                    Text("Always available via 'Draft Reply' button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Manual Features")
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Update: `MessageThreadViewModel.swift`**

```swift
@AppStorage("ai.faqAutoResponse.enabled") private var faqAutoResponseEnabled = true

func receiveMessage(_ message: MessageEntity) async {
    messages.append(message)

    // Only check FAQ if enabled in settings
    if faqAutoResponseEnabled && message.receiverId == CREATOR_ID {
        do {
            let faqResponse = try await aiService.checkFAQ(message.text)

            if faqResponse.isFAQ, let answer = faqResponse.answer {
                await sendMessage(answer, isAIGenerated: true)
            }
        } catch {
            print("FAQ check failed: \(error)")
        }
    }
}
```

**Add to Settings:**

```swift
// In SettingsView.swift
NavigationLink {
    AISettingsView()
} label: {
    Label("AI Settings", systemImage: "sparkles")
}
```

**Acceptance Criteria:**
- [ ] AI Settings view created
- [ ] Toggle for FAQ auto-response
- [ ] Toggle for auto-processing (future: can disable Cloud Function)
- [ ] Settings persist via @AppStorage
- [ ] FAQ auto-response respects toggle
- [ ] Accessible from main settings

**Estimate:** 30 min

---

## ⏱️ Time Breakdown

| Story | Description | Time |
|-------|-------------|------|
| 6.0 | Environment Configuration | 15 min |
| 6.1 | Firebase Cloud Functions Setup | 45 min |
| 6.2 | Auto-Processing Cloud Function (Features 1, 4, 5) | 2 hrs |
| 6.3 | FAQ Cloud Function (Feature 3) | 1.5 hrs |
| 6.4 | Smart Replies Cloud Function (Feature 2 + Advanced) | 2 hrs |
| 6.5 | iOS AI Service Integration | 30 min |
| 6.6 | Message Model Updates | 45 min |
| 6.7 | AI UI Components | 1.5 hrs |
| 6.8 | Error Handling & Degraded Mode | 1 hr |
| 6.9 | AI Settings UI | 30 min |
| **TOTAL** | | **~11.25 hours** |

### Adjustments from Original:
- **Added:** Story 6.0 Environment Configuration (+15 min)
- **Updated:** All functions to Firebase Functions v2 (modern API)
- **Updated:** Environment variables using `process.env` instead of `functions.config()`
- **Added:** Firestore security rules deployment
- **Removed:** n8n setup overhead (saved 30 min)
- **Simplified:** iOS integration (Cloud Functions SDK vs webhooks, saved 1 hr)
- **Added:** Error handling story (+1 hr)
- **Added:** Settings UI story (+30 min)
- **Updated:** FAQ search now uses Firestore native vector search (10x faster, cheaper than manual cosine similarity)
- **Added:** Firestore vector index setup requirement (critical dependency)
- **Added:** Production-only deployment (no separate dev environment)

**Realistic estimate: 11.25 hours** (vs original n8n approach: 12.5 hours)

---

## 🗄️ Data Model Changes

### MessageEntity (Add AI Metadata)
```swift
@Model
final class MessageEntity {
    // EXISTING (keep all):
    var id: String
    var conversationID: String
    var senderID: String
    var text: String
    var timestamp: Date
    var status: MessageStatus
    var readBy: [String]

    // NEW (add these):
    var aiCategory: String?           // "fan" | "business" | "spam" | "urgent"
    var aiSentiment: String?          // "positive" | "negative" | "urgent" | "neutral"
    var aiOpportunityScore: Int?      // 0-100 (only for business)
    var isAIGenerated: Bool = false   // True if FAQ auto-response
    var aiProcessedAt: Date?          // When AI processing completed
}
```

### Firestore Collections (New)

**FAQ Collection (Manual Creation):**
```
/faqs/{faqId}
  - question: String
  - answer: String
  - category: String
  - keywords: [String]
  - embedding: Vector<1536>  // FieldValue.vector() - Generated by Cloud Function

Example after embedding generation:
{
  "question": "What time do you stream?",
  "answer": "I stream Monday-Friday at 7pm EST on YouTube! See you there 🎮",
  "category": "schedule",
  "keywords": ["stream", "streaming", "time", "when", "schedule"],
  "embedding": {
    "_type": "vector",
    "_value": [0.123, 0.456, ...1536 dimensions total]
  }
}
```

**Required Index:**
- Collection: `faqs`
- Field: `embedding`
- Type: Vector
- Dimensions: 1536
- Distance Measure: COSINE

**Creator Profile Collection:**
```
/creator_profiles/andrew
  - personality: String
  - tone: String
  - examples: [String]
  - avoid: [String]
  - signature: String
```

### RTDB Structure (Updated)

**Messages with AI Metadata:**
```json
{
  "messages": {
    "conversation_123": {
      "msg_001": {
        "id": "msg_001",
        "text": "Hey, love your content!",
        "senderID": "fan_456",
        "receiverId": "andrew_creator_id",
        "timestamp": 1234567890,
        "aiCategory": "fan",
        "aiSentiment": "positive",
        "aiOpportunityScore": null,
        "isAIGenerated": false,
        "aiProcessedAt": 1234567891
      }
    }
  }
}
```

---

## 🔒 Firestore Security Rules

**Critical:** These rules must be deployed to protect FAQ and creator profile data.

**Create: `firestore.rules`**

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ========================================
    // FAQ Collection
    // ========================================
    // FAQs are read-only from client apps
    // Only Cloud Functions and admins can write
    match /faqs/{faqId} {
      // Anyone can read FAQs (needed for future FAQ browser feature)
      allow read: if true;

      // Only Cloud Functions can write (via Admin SDK)
      // Manual writes via Firebase Console only
      allow write: if false;
    }

    // ========================================
    // Creator Profiles Collection
    // ========================================
    // Profiles are read-only from client apps
    // Contains AI personality/tone settings
    match /creator_profiles/{profileId} {
      // Only authenticated users can read
      // (Needed for Smart Replies feature)
      allow read: if request.auth != null;

      // Only admins via Console can write
      allow write: if false;
    }

    // ========================================
    // User Profiles Collection (existing)
    // ========================================
    match /users/{userId} {
      // Users can read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;

      // Users can update their own profile
      allow update: if request.auth != null && request.auth.uid == userId;

      // System can create profiles
      allow create: if request.auth != null;
    }
  }
}
```

**Deploy Rules:**

```bash
# From project root
firebase deploy --only firestore:rules

# Verify deployment
# Go to Firebase Console > Firestore > Rules
# Check "Published" timestamp
```

**Security Notes:**
- FAQs are publicly readable (safe - no sensitive data)
- Creator profiles readable by authenticated users only
- All writes happen server-side via Cloud Functions (Admin SDK)
- Client apps cannot modify FAQ or creator profile data

**Testing Rules (Optional):**

```bash
# Install emulator suite if not already installed
npm install -g firebase-tools

# Start Firestore emulator with rules
firebase emulators:start --only firestore

# Rules are automatically loaded from firestore.rules
```

---

## ✅ Success Criteria

**Epic 6 is complete when:**

### Functional Requirements
- ✅ All fan DMs automatically categorized (fan/business/spam/urgent)
- ✅ All fan DMs have sentiment analysis (positive/negative/urgent/neutral)
- ✅ Business DMs have opportunity scores (0-100)
- ✅ FAQ questions get instant auto-responses (>80% confidence)
- ✅ "Draft Reply" button generates 3 options in Andrew's voice
- ✅ AI uses conversation context for relevant replies
- ✅ All AI features respond within latency targets (<1s auto, <8s smart replies)

### Technical Requirements
- ✅ 3 Cloud Functions deployed and operational
- ✅ AIService integrated into iOS app
- ✅ MessageEntity includes AI metadata fields
- ✅ Firestore has FAQ library with embeddings
- ✅ Creator profile with writing style examples stored
- ✅ All API calls properly secured (Firebase Auth)
- ✅ RTDB triggers auto-process messages
- ✅ Error handling with graceful degradation

### UX Requirements
- ✅ AI badges visible and color-coded on messages
- ✅ Smart reply picker shows 3 distinct options
- ✅ AI-generated FAQ responses clearly labeled
- ✅ Creator can edit AI drafts before sending
- ✅ Loading states for AI processing
- ✅ Error handling with user-friendly messages
- ✅ Settings to control AI behavior

### Scoring Requirements (40 points total)
- ✅ **Feature 1:** Auto-categorization working
- ✅ **Feature 2:** Response drafting in creator's voice
- ✅ **Feature 3:** FAQ auto-responder functional
- ✅ **Feature 4:** Sentiment analysis accurate
- ✅ **Feature 5:** Collaboration scoring for business messages
- ✅ **Advanced:** Context-Aware Smart Replies (3+ options, user style, <8s response)
- ✅ **Persona Fit:** All features clearly useful for creator managing fan DMs
- ✅ **Response Times:** Meet rubric targets

---

## 🚨 Risks & Mitigations

### Risk 1: Cloud Functions Cold Start Latency
**Impact:** First request after idle could be 2-3s slower
**Mitigation:**
- Keep functions "warm" with scheduled pings (1x/hour)
- Use min instances (1) for production (costs ~$5/month)
- Optimize function size (remove unused dependencies)
- Acceptable: Auto-processing is async, users won't notice

### Risk 2: OpenAI API Rate Limits
**Impact:** 429 errors during high usage
**Mitigation:**
- Start with Tier 1 limits (3,500 RPM)
- Implement exponential backoff in Cloud Functions
- Queue requests if rate limited
- Monitor usage in OpenAI dashboard
- Budget for Tier 2 upgrade if needed ($50 prepaid)

### Risk 3: OpenAI API Costs
**Impact:** Higher than expected costs
**Mitigation:**
- Use GPT-3.5-turbo for simple tasks (10x cheaper than GPT-4)
- Cache FAQ embeddings (one-time generation)
- Set budget alerts in OpenAI ($20, $50)
- Monitor per-feature costs
- Estimated: $15-25 for testing/demo

### Risk 4: Firebase Functions Quota Limits
**Impact:** Free tier may not be enough
**Mitigation:**
- Free tier: 2M invocations/month, 400K GB-sec
- Auto-processing: ~5K messages = 5K invocations
- Smart replies: ~500 requests = 500 invocations
- Total: ~10K invocations << 2M limit
- Acceptable: Will stay in free tier

### Risk 5: AI Accuracy Issues
**Impact:** Poor categorization/sentiment/replies
**Mitigation:**
- Use strong prompts with clear examples
- Test with real fan messages
- Tune confidence thresholds (FAQ: 80%, category: 70%)
- Allow manual override/correction
- Show confidence scores in UI
- Iterate on prompts based on testing

### Risk 6: Context Window Limits
**Impact:** Can't include enough conversation context
**Mitigation:**
- Limit to last 20 messages (fits in 8K context)
- GPT-4 Turbo has 128K context (plenty of headroom)
- Test with long conversations (100+ messages)
- Summarize old context if needed (future enhancement)

---

## 📦 Implementation Order

### Phase 0: Environment Setup (ALREADY DONE ✅)
1. ✅ OpenAI API key configured via `firebase functions:secrets:set`
2. ✅ Creator UID defined in all Cloud Functions: `UoLk9GtxDaaYGlI8Ah6RnCbXXbf2`
3. ✅ Production Firebase project active

### Phase 1: Infrastructure (45 min)
4. Initialize Firebase Cloud Functions (if not done)
5. Install OpenAI SDK and dependencies: `cd functions && npm install`
6. Configure `package.json` with correct versions
7. Deploy test function to production
8. Verify function logs: `firebase functions:log`

### Phase 2: Auto-Processing (2 hours)
9. Write auto-processing Cloud Function (categorization + sentiment + scoring)
10. Deploy and test with real messages in production
11. Update MessageEntity with AI fields
12. Update RTDB sync to include AI metadata
13. Add AI badges to MessageBubbleView

### Phase 3: FAQ Auto-Responder (2 hours)
14. Create Firestore vector index for `faqs.embedding` field (CRITICAL - must wait 5-10 min for build)
15. Create 10-15 FAQs in Firestore manually with keywords (use `/docs/data/faqs-preseed.json`)
16. Write Cloud Function to generate FAQ embeddings (uses FieldValue.vector())
17. Deploy and run generateFAQEmbeddings function in production
18. Verify embeddings stored correctly in Firestore Console
19. Write checkFAQ Cloud Function (uses native findNearest)
20. Deploy and test FAQ matching with real messages
21. Add AIService.checkFAQ() in iOS
22. Integrate FAQ auto-response in message receiving
23. Add AI-generated badge to UI

### Phase 4: Context-Aware Smart Replies (2 hours)
24. Create creator profile in Firestore manually (use template from PRD)
25. Write generateSmartReplies Cloud Function
26. Deploy and test with real conversation context
27. Create SmartReplyPickerView UI component
28. Add "Draft Reply" button to MessageThreadView
29. Test end-to-end with real production conversations

### Phase 5: Error Handling & Settings (1.5 hours)
30. Add timeout and error handling to Cloud Functions
31. Deploy and test error scenarios in production
32. Add graceful degradation to iOS
33. Create AI Settings UI
34. Wire up settings toggles

### Phase 6: Security & Polish (1 hour)
35. Deploy Firestore security rules to production
36. Test all 5 AI features end-to-end in production
37. Verify latency meets targets
38. Test error handling (network failures, timeouts)
39. Polish UI animations and loading states
40. Update documentation

**Total: ~11.25 hours**

---

## 📚 References

- **Project Brief:** `docs/project-brief.md` (Content Creator persona, 5 required features)
- **Scoring Rubric:** `docs/scoring.md` (Section 3: 30 pts AI + 10 pts Advanced)
- **Tech Stack:** `docs/architecture/technology-stack.md` (OpenAI, Firebase)
- **Epic 5:** Single-Creator Platform (provides inbox for AI to manage)
- **Firebase Functions Docs:** https://firebase.google.com/docs/functions
- **OpenAI API Docs:** https://platform.openai.com/docs

---

## 🎬 Next Steps

**After Epic 6 Completion:**
1. ✅ All 5 AI features implemented and working
2. ✅ Advanced AI Capability (Context-Aware Smart Replies) complete
3. ✅ **40 points secured** (AI Features + Advanced)
4. 🚀 **Epic 7: Documentation & Demo Video** (avoid -30 points in penalties)
5. 🚀 **Epic 8: Testing & Polish** (ensure A- or A grade)

**Current Points Estimate:**
- Core Messaging: 28-30/35 ✅
- Mobile Quality: 15-17/20 ✅
- **AI Features: 28-30/30** ✅ (after Epic 6)
- **Advanced AI: 9-10/10** ✅ (after Epic 6)
- Technical: 7-8/10 ✅
- Docs/Deploy: Need Epic 7 (currently 0/5)

**Total: 87-95 points (A-/A range) with Epic 6 + Epic 7**

---

**Epic Status:** 🟢 Ready to Implement
**Blockers:** None (Epic 5 completed)
**Risk Level:** Low (Firebase + OpenAI is proven stack)
**Strategic Value:** CRITICAL - 40% of total grade

**Recommendation: START EPIC 6 IMMEDIATELY. Firebase Cloud Functions approach is faster, cheaper, and more reliable than n8n.**
