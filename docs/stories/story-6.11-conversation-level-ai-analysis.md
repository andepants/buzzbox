# Story 6.11: Conversation-Level AI Analysis & Visual Indicators

**Epic:** Epic 6 - AI-Powered Creator Inbox
**Priority:** P1 (Enhancement to existing AI features)
**Estimated Time:** 4 hours
**Dependencies:** Story 6.2 (Auto-Processing Cloud Function)
**Status:** 📝 Draft

---

## 📋 User Story

**As Andrew (the creator), I want AI-powered visual indicators on each conversation card so I can quickly assess business opportunities, fan sentiment, and fan types at a glance without opening individual conversations.**

---

## 🎯 What This Story Delivers

### Current Behavior (Story 6.2)
- AI analyzes individual messages only
- Sentiment, category, and business score visible inside conversation
- No conversation-level summary
- Must open each conversation to see AI insights

### New Behavior (Story 6.11)
- **Conversation-level AI analysis** of entire conversation history
- **Visual sentiment border** around conversation cards (subtle green/red/neutral)
- **Business score badge** (0-10 scale) for business opportunities
- **Category badge** auto-classifies fans (fan, super fan, business, spam, urgent)
- **Smart triggering** - analyzes when creator opens inbox if new messages exist
- **Spam handling** - grayed out conversations for spam category
- **Urgent highlighting** - visually distinct for urgent category

### What's New
- 🆕 Conversation-level AI metadata (extends message-level analysis)
- 🆕 Sentiment color-coded borders on conversation cards
- 🆕 Business opportunity score badges (0-10 scale, color-coded)
- 🆕 Fan type categorization (fan, super fan, business, spam, urgent)
- 🆕 Automatic re-analysis on new messages
- 🆕 Visual spam filtering (grayed out)
- 🆕 Urgent category special treatment

---

## 🎨 Visual Design

### Sentiment Border (Subtle Accent)
- **Positive:** 2pt green border (`Color.green.opacity(0.3)`)
- **Negative:** 2pt red border (`Color.red.opacity(0.3)`)
- **Neutral:** No border or 1pt gray border (`Color.gray.opacity(0.15)`)
- **Urgent:** 2pt orange border (`Color.orange.opacity(0.4)`)
- **Position:** Full conversation card border
- **Style:** Rounded corners matching card style

### Badge Layout
**Position:** Right side of username row (HStack with username)

```
[Profile Pic]  Username  [Creator Badge]  [Category Badge] [Business Score Badge]  Time
               Last message preview...
```

### Category Badge Specifications

**Fan Badge**
- **Text:** "Fan"
- **Color:** Blue (`Color.blue`)
- **Icon:** None (text only)

**Super Fan Badge**
- **Text:** "Super Fan"
- **Color:** Purple (`Color.purple`)
- **Icon:** `star.fill` (optional)

**Business Badge**
- **Text:** "Business"
- **Color:** Green (`Color.green`)
- **Icon:** `briefcase.fill` (optional)

**Spam Badge**
- **Text:** "Spam"
- **Color:** Gray (`Color.gray`)
- **Icon:** None
- **Special:** Entire conversation row has 50% opacity

**Urgent Badge**
- **Text:** "Urgent"
- **Color:** Orange (`Color.orange`)
- **Icon:** `exclamationmark.circle.fill`
- **Special:** Pulsing animation (subtle)

### Business Score Badge (Only for Business Category)

**Score Ranges & Colors:**
- **7-10:** Green background (`Color.green`)
- **4-6:** Yellow background (`Color.yellow`)
- **0-3:** Red background (`Color.red`)

**Badge Design:**
- **Shape:** Pill (capsule)
- **Size:** 24pt height, auto width
- **Text:** "\(score)/10" (white text, bold, 11pt)
- **Position:** After category badge, before timestamp

---

## 🏗️ Technical Implementation

### 1. Cloud Function Extension

**New Function: `functions/src/conversation-analysis.ts`**

Create new Cloud Function that analyzes entire conversations (not individual messages):

```typescript
/**
 * Analyze entire conversation for creator inbox
 * Generates conversation-level sentiment, category, and business score
 *
 * Triggered: HTTP Callable (called when creator opens inbox)
 * Input: { conversationID: string, forceRefresh?: boolean }
 * Output: { sentiment: string, category: string, businessScore?: number }
 */
export const analyzeConversation = onCall({
  region: 'us-central1',
  secrets: ['OPENAI_API_KEY'],
  timeoutSeconds: 30, // Analyzing 100 messages may take longer
}, async (request) => {
  const { conversationID, forceRefresh } = request.data;
  const auth = request.auth;

  // Only allow creator to call this function
  if (!auth || auth.uid !== CREATOR_UID) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only the creator can analyze conversations'
    );
  }

  // Check if analysis already exists and is fresh
  const conversationRef = admin.database().ref(`/conversations/${conversationID}`);
  const conversationSnapshot = await conversationRef.once('value');
  const conversation = conversationSnapshot.val();

  // Skip if already analyzed and no new messages (unless force refresh)
  if (!forceRefresh && conversation?.aiAnalyzedAt) {
    const lastMessageTimestamp = conversation.lastMessageTimestamp || 0;
    const lastAnalyzedTimestamp = conversation.aiAnalyzedAt || 0;

    if (lastAnalyzedTimestamp >= lastMessageTimestamp) {
      logger.info('Conversation already analyzed, no new messages', {
        conversationID,
        lastAnalyzedTimestamp,
        lastMessageTimestamp,
      });

      return {
        sentiment: conversation.aiSentiment,
        category: conversation.aiCategory,
        businessScore: conversation.aiBusinessScore,
        cached: true,
      };
    }
  }

  // Fetch last 100 messages for analysis
  const messagesSnapshot = await admin.database()
    .ref(`/messages/${conversationID}`)
    .orderByChild('timestamp')
    .limitToLast(100)
    .once('value');

  const messages: Message[] = [];
  messagesSnapshot.forEach((child) => {
    messages.push(child.val());
  });

  // Skip if no messages
  if (messages.length === 0) {
    logger.info('No messages in conversation, skipping analysis', {
      conversationID,
    });
    return { sentiment: 'neutral', category: 'fan', cached: false };
  }

  // Initialize OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  logger.info('🔄 Starting conversation-level AI analysis...', {
    conversationID,
    messageCount: messages.length,
  });

  // Run parallel analysis
  const [sentiment, category] = await Promise.all([
    analyzeConversationSentiment(openai, messages),
    categorizeConversation(openai, messages),
  ]);

  // Only score business opportunities if category is 'business'
  const businessScore = category === 'business' ?
    await scoreConversationOpportunity(openai, messages) :
    null;

  logger.info('✅ Conversation analysis complete', {
    conversationID,
    sentiment,
    category,
    businessScore,
  });

  // Update conversation with AI metadata
  await conversationRef.update({
    aiSentiment: sentiment,
    aiCategory: category,
    aiBusinessScore: businessScore,
    aiAnalyzedAt: admin.database.ServerValue.TIMESTAMP,
  });

  return {
    sentiment,
    category,
    businessScore,
    cached: false,
  };
});

/**
 * Analyze overall conversation sentiment
 * Returns: positive | negative | neutral | urgent
 */
async function analyzeConversationSentiment(
  openai: OpenAI,
  messages: Message[]
): Promise<string> {
  // Build conversation context (last 100 messages)
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? 'Creator' : 'Fan'}: ${m.text}`)
    .join('\n');

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: `Analyze the overall sentiment of this conversation between a tech creator and a fan.
Choose ONE sentiment that best represents the OVERALL tone of the conversation:
- positive: Generally friendly, appreciative, enthusiastic
- negative: Frustrated, angry, disappointed, critical
- urgent: Time-sensitive, requires immediate attention
- neutral: Informational, matter-of-fact, no strong emotion

Consider the entire conversation history, not just individual messages.
Respond with ONLY the sentiment word (lowercase).`,
      },
      {
        role: 'user',
        content: conversationContext,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const sentiment = completion.choices[0].message.content?.trim().toLowerCase() || 'neutral';

  // Validate
  if (!['positive', 'negative', 'urgent', 'neutral'].includes(sentiment)) {
    logger.warn('Invalid sentiment returned, defaulting to neutral', {
      returned: sentiment,
    });
    return 'neutral';
  }

  return sentiment;
}

/**
 * Categorize conversation participant
 * Returns: fan | super_fan | business | spam | urgent
 */
async function categorizeConversation(
  openai: OpenAI,
  messages: Message[]
): Promise<string> {
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? 'Creator' : 'Fan'}: ${m.text}`)
    .join('\n');

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: `Categorize this fan based on their conversation with a tech content creator.
Choose the SINGLE MOST RELEVANT category:
- fan: Regular fan (appreciative, asks questions, casual engagement)
- super_fan: Highly engaged fan (frequent messages, deep knowledge of content, very supportive)
- business: Business inquiry, collaboration, sponsorship, partnership opportunity
- spam: Spam, advertisements, phishing, irrelevant/inappropriate content
- urgent: Time-sensitive request requiring immediate attention (live issue, emergency, deadline)

Respond with ONLY the category word (lowercase, use underscore for super_fan).`,
      },
      {
        role: 'user',
        content: conversationContext,
      },
    ],
    temperature: 0.3,
    max_tokens: 10,
  });

  const category = completion.choices[0].message.content?.trim().toLowerCase() || 'fan';

  // Validate
  if (!['fan', 'super_fan', 'business', 'spam', 'urgent'].includes(category)) {
    logger.warn('Invalid category returned, defaulting to fan', {
      returned: category,
    });
    return 'fan';
  }

  return category;
}

/**
 * Score business opportunity for entire conversation
 * Returns: 0-10 (only called if category is 'business')
 */
async function scoreConversationOpportunity(
  openai: OpenAI,
  messages: Message[]
): Promise<number> {
  const conversationContext = messages
    .slice(-100)
    .map((m) => `${m.senderID === CREATOR_UID ? 'Creator' : 'Fan'}: ${m.text}`)
    .join('\n');

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: `Score this business collaboration opportunity from 0-10 based on the ENTIRE conversation.

Scoring criteria for a tech content creator:
- 8-10: High-value partnership (known brand, clear budget, strong fit, serious engagement)
- 5-7: Moderate opportunity (legitimate, needs vetting, shows promise)
- 2-4: Low-value (generic pitch, unclear value, minimal engagement)
- 0-1: Not a real opportunity (spam, completely generic outreach)

Consider:
- Conversation depth and engagement level
- Specificity of the opportunity (vague vs detailed)
- Brand alignment with tech content
- Professionalism and legitimacy
- Follow-through in conversation

Respond with ONLY a number from 0-10.`,
      },
      {
        role: 'user',
        content: conversationContext,
      },
    ],
    temperature: 0.5,
    max_tokens: 10,
  });

  const scoreText = completion.choices[0].message.content?.trim() || '5';
  const score = parseInt(scoreText, 10);

  // Validate score
  if (isNaN(score) || score < 0 || score > 10) {
    logger.warn('Invalid score returned, defaulting to 5', {
      returned: scoreText,
    });
    return 5;
  }

  return score;
}
```

### 2. SwiftData Model Updates

**Update: `buzzbox/Core/Models/ConversationEntity.swift`**

Add new AI metadata properties to ConversationEntity:

```swift
// MARK: - AI Conversation Analysis (Story 6.11)

/// Overall conversation sentiment (positive, negative, neutral, urgent)
var aiSentiment: String?

/// Conversation category (fan, super_fan, business, spam, urgent)
var aiCategory: String?

/// Business opportunity score (0-10, only set if category is 'business')
var aiBusinessScore: Int?

/// Timestamp when conversation was last analyzed by AI
var aiAnalyzedAt: Date?

/// Number of new messages since last analysis (for triggering re-analysis)
var messageCountSinceAnalysis: Int = 0
```

**Update initializer:**
```swift
init(
    // ... existing parameters
) {
    // ... existing initialization
    self.aiSentiment = nil
    self.aiCategory = nil
    self.aiBusinessScore = nil
    self.aiAnalyzedAt = nil
    self.messageCountSinceAnalysis = 0
}
```

### 3. Service Layer

**New Service: `buzzbox/Core/Services/ConversationAnalysisService.swift`**

```swift
/// Service for analyzing conversations with AI
/// [Source: Story 6.11 - Conversation-Level AI Analysis]
@MainActor
final class ConversationAnalysisService {
    static let shared = ConversationAnalysisService()

    private let functions = Functions.functions()

    private init() {}

    /// Analyze a conversation and update local SwiftData entity
    /// - Parameters:
    ///   - conversation: ConversationEntity to analyze
    ///   - forceRefresh: Force re-analysis even if already analyzed
    /// - Returns: True if analysis was performed, false if cached
    func analyzeConversation(
        _ conversation: ConversationEntity,
        forceRefresh: Bool = false
    ) async throws -> Bool {
        // Skip if already analyzed and no new messages (unless force refresh)
        if !forceRefresh,
           conversation.aiAnalyzedAt != nil,
           conversation.messageCountSinceAnalysis == 0 {
            print("📊 Conversation already analyzed, skipping")
            return false
        }

        print("📊 Analyzing conversation: \(conversation.id)")

        // Call Cloud Function
        let callable = functions.httpsCallable("analyzeConversation")
        let result = try await callable.call([
            "conversationID": conversation.id,
            "forceRefresh": forceRefresh
        ])

        // Parse result
        guard let data = result.data as? [String: Any],
              let sentiment = data["sentiment"] as? String,
              let category = data["category"] as? String else {
            throw NSError(domain: "ConversationAnalysisService", code: -1)
        }

        let businessScore = data["businessScore"] as? Int
        let cached = data["cached"] as? Bool ?? false

        // Update local SwiftData entity
        conversation.aiSentiment = sentiment
        conversation.aiCategory = category
        conversation.aiBusinessScore = businessScore
        conversation.aiAnalyzedAt = Date()
        conversation.messageCountSinceAnalysis = 0

        print("✅ Conversation analysis complete: \(sentiment), \(category), \(businessScore ?? 0)")

        return !cached
    }

    /// Analyze all conversations in inbox (batch operation)
    /// Only analyzes conversations with new messages since last analysis
    func analyzeAllConversations(_ conversations: [ConversationEntity]) async {
        print("📊 Analyzing \(conversations.count) conversations...")

        for conversation in conversations {
            // Only analyze if there are new messages
            if conversation.messageCountSinceAnalysis > 0 {
                do {
                    _ = try await analyzeConversation(conversation)
                } catch {
                    print("❌ Failed to analyze conversation \(conversation.id): \(error)")
                }
            }
        }

        print("✅ Batch analysis complete")
    }
}
```

### 4. UI Updates

**Update: `buzzbox/Features/Chat/Views/ConversationRowView.swift`**

Add sentiment border and badge UI:

```swift
var body: some View {
    HStack(spacing: 12) {
        // ... existing profile picture code

        // Conversation details
        VStack(alignment: .leading, spacing: 4) {
            // Name, badges, and timestamp row
            HStack(spacing: 6) {
                // Username
                if conversation.isGroup {
                    Text(conversation.displayName ?? "Channel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(recipientUser?.displayName ?? "Loading...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                // Creator badge
                if !conversation.isGroup && recipientUser?.userType == .creator {
                    CreatorBadgeView(size: .small)
                }

                // 🆕 AI Category Badge (Story 6.11)
                if let category = conversation.aiCategory {
                    categoryBadge(for: category)
                }

                // 🆕 Business Score Badge (Story 6.11)
                if let score = conversation.aiBusinessScore {
                    businessScoreBadge(score: score)
                }

                // Lock icon for creator-only channels
                if conversation.isGroup && conversation.isCreatorOnly {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lastMessageAt = conversation.lastMessageAt {
                    Text(lastMessageAt, style: .relative)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            // ... existing last message code
        }
    }
    .padding(.vertical, 8)
    // 🆕 Sentiment border (Story 6.11)
    .background(
        RoundedRectangle(cornerRadius: 12)
            .stroke(sentimentBorderColor, lineWidth: sentimentBorderWidth)
    )
    // 🆕 Spam opacity (Story 6.11)
    .opacity(conversation.aiCategory == "spam" ? 0.5 : 1.0)
    // ... existing task/onDisappear code
}

// MARK: - 🆕 AI Badge Subviews (Story 6.11)

/// Category badge for conversation
private func categoryBadge(for category: String) -> some View {
    HStack(spacing: 3) {
        // Icon for certain categories
        if category == "urgent" {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
        } else if category == "super_fan" {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
        } else if category == "business" {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 10))
        }

        // Text
        Text(categoryDisplayText(for: category))
            .font(.system(size: 11, weight: .semibold))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(categoryColor(for: category))
    .foregroundStyle(.white)
    .clipShape(Capsule())
}

/// Business score badge (0-10)
private func businessScoreBadge(score: Int) -> some View {
    Text("\(score)/10")
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(businessScoreColor(for: score))
        .foregroundStyle(.white)
        .clipShape(Capsule())
}

// MARK: - Helper Methods

private var sentimentBorderColor: Color {
    guard let sentiment = conversation.aiSentiment else { return .clear }

    switch sentiment {
    case "positive":
        return .green.opacity(0.3)
    case "negative":
        return .red.opacity(0.3)
    case "urgent":
        return .orange.opacity(0.4)
    default:
        return .gray.opacity(0.15)
    }
}

private var sentimentBorderWidth: CGFloat {
    guard let sentiment = conversation.aiSentiment else { return 0 }

    switch sentiment {
    case "neutral":
        return 1
    default:
        return 2
    }
}

private func categoryColor(for category: String) -> Color {
    switch category {
    case "fan":
        return .blue
    case "super_fan":
        return .purple
    case "business":
        return .green
    case "spam":
        return .gray
    case "urgent":
        return .orange
    default:
        return .blue
    }
}

private func categoryDisplayText(for category: String) -> String {
    switch category {
    case "super_fan":
        return "Super Fan"
    default:
        return category.capitalized
    }
}

private func businessScoreColor(for score: Int) -> Color {
    switch score {
    case 7...10:
        return .green
    case 4...6:
        return .yellow
    case 0...3:
        return .red
    default:
        return .gray
    }
}
```

### 5. ViewModel Integration

**Update: `buzzbox/Features/Chat/ViewModels/ConversationListViewModel.swift`**

Add analysis trigger when view appears:

```swift
/// Analyze all conversations when creator opens inbox
/// [Source: Story 6.11 - Conversation-Level AI Analysis]
func analyzeConversationsIfNeeded() async {
    // Only run for creator
    guard isCreator else { return }

    // Get conversations with new messages
    let conversationsToAnalyze = conversations.filter {
        $0.messageCountSinceAnalysis > 0
    }

    guard !conversationsToAnalyze.isEmpty else {
        print("📊 No conversations need analysis")
        return
    }

    print("📊 Analyzing \(conversationsToAnalyze.count) conversations with new messages...")

    await ConversationAnalysisService.shared.analyzeAllConversations(conversationsToAnalyze)
}
```

**Update `ConversationListView.swift`:**

```swift
.task {
    await viewModel.loadConversations()
    // 🆕 Analyze conversations when view appears (Story 6.11)
    await viewModel.analyzeConversationsIfNeeded()
}
```

### 6. Message Count Tracking

**Update: `buzzbox/Core/Services/MessageService.swift`**

Increment message count when new message arrives:

```swift
// After saving message to SwiftData
conversation.messageCountSinceAnalysis += 1
```

---

## ✅ Acceptance Criteria

1. **Cloud Function**
   - [ ] New `analyzeConversation` Cloud Function created in `functions/src/conversation-analysis.ts`
   - [ ] Function analyzes last 100 messages for conversation context
   - [ ] Parallel processing (sentiment + category) for speed
   - [ ] Business score only calculated if category is "business"
   - [ ] Function only callable by creator (security check)
   - [ ] Skips analysis if no new messages since last analysis (unless force refresh)

2. **Data Model**
   - [ ] `ConversationEntity` has new fields: `aiSentiment`, `aiCategory`, `aiBusinessScore`, `aiAnalyzedAt`, `messageCountSinceAnalysis`
   - [ ] Fields properly initialized in `init()`
   - [ ] SwiftData migration handled (optional fields)

3. **Service Layer**
   - [ ] `ConversationAnalysisService` created
   - [ ] `analyzeConversation()` method calls Cloud Function and updates SwiftData
   - [ ] `analyzeAllConversations()` batch method for inbox-level analysis
   - [ ] Error handling for network failures

4. **UI - Sentiment Border**
   - [ ] Green border for positive sentiment (2pt, 30% opacity)
   - [ ] Red border for negative sentiment (2pt, 30% opacity)
   - [ ] Neutral gray border (1pt, 15% opacity)
   - [ ] Orange border for urgent sentiment (2pt, 40% opacity)
   - [ ] Border applied to entire conversation card

5. **UI - Category Badge**
   - [ ] Badge displays next to username on right side
   - [ ] Fan: blue, "Fan" text
   - [ ] Super Fan: purple, "Super Fan" text with star icon
   - [ ] Business: green, "Business" text with briefcase icon
   - [ ] Spam: gray, "Spam" text
   - [ ] Urgent: orange, "Urgent" text with exclamation icon

6. **UI - Business Score Badge**
   - [ ] Only shown if category is "business"
   - [ ] Displays "\(score)/10" format
   - [ ] Color-coded: 7-10 green, 4-6 yellow, 0-3 red
   - [ ] Positioned after category badge

7. **UI - Spam Handling**
   - [ ] Spam conversations have 50% opacity on entire row
   - [ ] Still clickable/accessible (not hidden)

8. **Triggering Logic**
   - [ ] Analysis triggers when creator opens ConversationListView
   - [ ] Only analyzes conversations with `messageCountSinceAnalysis > 0`
   - [ ] `messageCountSinceAnalysis` increments on each new message
   - [ ] `messageCountSinceAnalysis` resets to 0 after analysis
   - [ ] Cached results used if no new messages (no redundant API calls)

9. **Testing**
   - [ ] Test with conversations of varying lengths (1, 10, 100+ messages)
   - [ ] Verify sentiment detection accuracy
   - [ ] Verify category accuracy (fan vs super fan vs business)
   - [ ] Verify business score only appears for business category
   - [ ] Test spam conversations are grayed out
   - [ ] Test urgent conversations have distinct visual treatment
   - [ ] Verify re-analysis triggers on new messages
   - [ ] Test Cloud Function with Firebase Emulator

---

## 🧪 Testing Strategy

### Unit Tests
- ConversationAnalysisService.analyzeConversation() success/failure
- Sentiment/category/score parsing from Cloud Function response
- Badge color logic for all score ranges
- Border color logic for all sentiments

### Integration Tests
- End-to-end analysis flow (Cloud Function → SwiftData update → UI refresh)
- Batch analysis of multiple conversations
- Caching behavior (skip analysis if no new messages)
- Message count increment on new message

### Manual Testing Checklist
1. **Positive Sentiment Conversation**
   - Send 10+ positive messages
   - Open inbox, verify green border appears
   - Verify "Fan" category badge shows

2. **Business Conversation**
   - Send business inquiry messages
   - Verify "Business" badge shows
   - Verify business score badge appears (0-10)
   - Verify score color matches range (green/yellow/red)

3. **Spam Conversation**
   - Create spam-like messages
   - Verify conversation row is grayed out (50% opacity)
   - Verify "Spam" badge shows

4. **Urgent Conversation**
   - Send urgent time-sensitive message
   - Verify orange border appears
   - Verify "Urgent" badge with exclamation icon shows

5. **Re-Analysis Trigger**
   - Open inbox (analysis runs)
   - Send new message
   - Re-open inbox
   - Verify analysis runs again (check logs)

6. **Performance**
   - Test with 20+ conversations
   - Verify UI doesn't freeze during batch analysis
   - Verify cached results load instantly

---

## 📝 Dev Notes

### Relevant Source Tree
```
buzzbox/
├── Core/
│   ├── Models/
│   │   └── ConversationEntity.swift (ADD: AI analysis fields)
│   └── Services/
│       └── ConversationAnalysisService.swift (NEW)
├── Features/
│   └── Chat/
│       ├── Views/
│       │   └── ConversationRowView.swift (UPDATE: badges + border)
│       └── ViewModels/
│           └── ConversationListViewModel.swift (UPDATE: trigger analysis)
functions/
└── src/
    └── conversation-analysis.ts (NEW)
```

### Key Technical Decisions

1. **Why analyze last 100 messages?**
   - Balances context depth with API costs
   - 100 messages typically covers 1-2 weeks of conversation
   - Can be adjusted if needed (make it configurable)

2. **Why not analyze on every message?**
   - Cost optimization (OpenAI API calls)
   - Performance (avoid blocking message send)
   - Batch analysis on inbox open is more efficient

3. **Why conversation-level vs message-level?**
   - Message-level (Story 6.2) for in-conversation insights
   - Conversation-level (Story 6.11) for inbox overview/triage
   - Both serve different use cases

4. **Why 0-10 scale instead of 0-100?**
   - Simpler UI (badge fits better)
   - Easier for creator to interpret at a glance
   - Aligns with human rating scales (more intuitive)

### Firebase Emulator Testing

```bash
# Start emulators
cd /Users/andre/coding/buzzbox
firebase emulators:start --only functions

# Test conversation analysis
curl -X POST http://localhost:5001/buzzbox-ios/us-central1/analyzeConversation \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "conversationID": "test-conversation-id",
      "forceRefresh": true
    }
  }'
```

### OpenAI Cost Estimation
- **Model:** GPT-4o-mini
- **Cost:** ~$0.00015 per conversation (100 messages, 3 API calls)
- **Scale:** 100 conversations/day = $0.015/day = $0.45/month
- **Very affordable for this use case**

---

## 📦 Files to Create/Modify

### New Files
- `functions/src/conversation-analysis.ts` (new Cloud Function)
- `buzzbox/Core/Services/ConversationAnalysisService.swift` (new service)

### Modified Files
- `buzzbox/Core/Models/ConversationEntity.swift` (add AI fields)
- `buzzbox/Features/Chat/Views/ConversationRowView.swift` (add badges + border)
- `buzzbox/Features/Chat/ViewModels/ConversationListViewModel.swift` (trigger analysis)
- `buzzbox/Core/Services/MessageService.swift` (increment message count)
- `functions/src/index.ts` (export new function)

---

## 🚀 Deployment

### Development
```bash
# Deploy Cloud Function to emulator (local testing)
firebase emulators:start --only functions

# Run iOS app pointing to emulator
# (Firebase SDK auto-detects emulator on localhost)
```

### Production
```bash
# Deploy Cloud Function
cd /Users/andre/coding/buzzbox/functions
npm run build
firebase deploy --only functions:analyzeConversation

# Deploy iOS app
# (build and upload to TestFlight)
```

---

## 🎯 Success Metrics

- **Conversation analysis accuracy:** >85% correct sentiment/category
- **Business score relevance:** Creator agrees with score in >80% of cases
- **UI performance:** No lag when opening inbox with 20+ conversations
- **API cost:** <$1/month for typical usage (100 conversations/day)
- **Creator productivity:** 30% faster inbox triage (measured by time to first reply)

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-24 | 1.0 | Initial story creation | Claude (Sonnet 4.5) |
