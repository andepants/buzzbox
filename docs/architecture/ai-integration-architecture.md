# AI Integration Architecture

### 6.1 AI Feature Flow

**Automatic (Triggered):**
1. User sends/receives message → Firestore write
2. Cloud Function trigger: `onMessageCreated`
3. Auto-categorize message (Fan/Business/Spam/Urgent)
4. If Business: Auto-score opportunity (0-100)
5. Update Firestore message document with AI metadata
6. Real-time listener in iOS app receives update
7. UI automatically displays category badge and score

**On-Demand (Callable):**
1. User taps "Draft Reply" button
2. iOS app calls Cloud Function: `generateSmartReplyCallable`
3. Cloud Function fetches context from Supermemory (RAG)
4. Cloud Function fetches creator's writing style from Firestore
5. Build prompt with context + style, call OpenAI GPT-4
6. Return generated draft to iOS app
7. Display draft in editable card, user can edit/send/dismiss

### 6.2 Cloud Functions Architecture

**5 Core Functions:**

1. **onMessageCreated** (Triggered)
   - Auto-categorize: Fan/Business/Spam/Urgent
   - If Business: Score opportunity
   - Update message document
   - Execution: ~2 seconds

2. **generateSmartReplyCallable** (Callable)
   - Fetch context from Supermemory
   - Fetch creator's voice patterns
   - Generate personalized reply via GPT-4
   - Execution: ~3 seconds

3. **detectFAQCallable** (Callable)
   - Match incoming message to FAQ library
   - Return suggested answer if confidence > 70%
   - Execution: ~2 seconds

4. **analyzeSentimentCallable** (Callable)
   - Analyze emotional tone (positive/negative/urgent/neutral)
   - Determine intensity (low/medium/high)
   - Execution: ~2 seconds

5. **scoreOpportunityCallable** (Callable)
   - Score business messages (0-100)
   - Breakdown: monetary value, brand fit, legitimacy, urgency
   - Execution: ~3 seconds

**Environment Variables:**
- `OPENAI_API_KEY`: Stored in Cloud Functions config (never in iOS app)
- `SUPERMEMORY_API_KEY`: Stored in Cloud Functions config
- `FIREBASE_*`: Admin SDK credentials

### 6.3 RAG Pipeline (Supermemory)

**Context Retrieval:**
- iOS app stores conversations to Supermemory periodically
- When generating smart reply, Cloud Function queries Supermemory
- Vector search returns top 5 relevant past conversation snippets
- Snippets provide context for personalized AI responses

**Storage Strategy:**
- Store after every 10 messages in a conversation
- Store when conversation is archived or completed
- Privacy: User can disable Supermemory storage in settings

**Implementation Details:**
📖 See [Supermemory Integration Guide](./supermemory-integration-guide.md) for:
- Authentication setup with Bearer tokens
- Cloud Functions for automatic message storage
- RAG query implementation for smart replies
- Error handling with retry strategies
- Privacy controls and data deletion patterns

### 6.4 AI Cost Optimization

- **Caching:** Cache AI responses for similar messages (7-day TTL)
- **Rate Limiting:** 100 AI requests per user per hour
- **Model Selection:** GPT-3.5-turbo for categorization, GPT-4 for smart replies
- **Selective Processing:** Only run expensive features on-demand
- **Prompt Optimization:** Keep prompts concise, use function calling
