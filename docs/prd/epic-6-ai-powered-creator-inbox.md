# Epic 6: AI-Powered Creator Inbox

**Phase:** Day 3-5 (AI Features Implementation)
**Priority:** P0 (CRITICAL - Worth 30 Points for AI Features + 10 Points for Advanced Capability)
**Estimated Time:** 8-9 hours
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

> **Advanced AI Capability (10 points)**
> - Context-Aware Smart Replies: Learns user style accurately, generates authentic-sounding replies, provides 3+ relevant options

**Current State:** After Epic 5, we have a single-creator platform where Andrew receives DMs from fans.

**Problem:** Andrew has no AI assistance to manage fan communication at scale.

**Solution:** Build 5 AI features + Context-Aware Smart Replies using n8n workflows.

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

---

## 🏗️ Architecture Overview

### n8n-Based AI Pipeline

```
iOS App → n8n Webhooks → OpenAI GPT-4 → Firestore → iOS App
         ↑
    All AI logic in n8n workflows
```

**Why n8n Instead of Cloud Functions:**
- ✅ Visual workflow builder (easier to debug/modify)
- ✅ All AI logic in one place
- ✅ No Cloud Functions deployment needed
- ✅ Developer preference and familiarity

**Trade-offs:**
- ⚠️ Adds 200-500ms latency (extra network hop)
- ⚠️ Requires n8n hosting (n8n Cloud or self-hosted)
- ⚠️ Slight deviation from tech stack (acceptable for this use case)

---

## 📊 High-Level Implementation Overview

### 1. n8n Workflows (3 workflows)

**Workflow 1: Auto-Processing (Features 1, 4, 5)**
- **Trigger:** Webhook receives new message
- **Processing:**
  1. Categorize message (fan/business/spam/urgent)
  2. Analyze sentiment (positive/negative/urgent/neutral)
  3. Score opportunity (0-100 if business)
- **Output:** `{ category, sentiment, score }`
- **Latency:** <2s (scoring requirement)

**Workflow 2: FAQ Auto-Responder (Feature 3)**
- **Trigger:** Webhook receives message
- **Processing:**
  1. Embed message with OpenAI embeddings
  2. Vector search Firestore FAQ collection
  3. If confidence >80% → Return FAQ answer
- **Output:** `{ isFAQ: true, answer: "..." }` or `{ isFAQ: false }`
- **Latency:** <2s
- **Auto-sends:** If FAQ match, iOS automatically sends response

**Workflow 3: Context-Aware Smart Replies (Features 2 + Advanced)**
- **Trigger:** User taps "Draft Reply" button
- **Processing:**
  1. Fetch last 20 messages from Firestore (conversation context)
  2. Fetch Andrew's writing style examples from Firestore
  3. Call OpenAI GPT-4 with:
     - System prompt: Andrew's personality/tone
     - Context: Recent conversation history
     - Task: Generate 3 reply options (short/medium/detailed)
- **Output:** `{ drafts: [option1, option2, option3] }`
- **Latency:** <8s (advanced capability target)
- **Satisfies:** "Context-Aware Smart Replies" requirement (10 points)

### 2. iOS Integration

**New Service: `AIService.swift`**
- `processMessage()` → Calls Workflow 1, updates message metadata
- `checkFAQ()` → Calls Workflow 2, auto-responds if match
- `generateSmartReplies()` → Calls Workflow 3, displays 3 options

**UI Updates:**
- AI badges on messages (category, sentiment, score)
- "Draft Reply" button in message composer
- Smart reply selection UI (3 options)
- Auto-response indicator for FAQ answers

### 3. Firestore Data Structures

**FAQ Collection:**
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
        "tone": "friendly, casual, authentic",
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

### Story 6.1: n8n Setup & Configuration (30 min)

**As a developer, I want to set up n8n infrastructure so I can deploy AI workflows.**

**Acceptance Criteria:**
- [ ] n8n instance deployed (n8n Cloud or self-hosted)
- [ ] OpenAI API key configured in n8n credentials
- [ ] Firestore service account configured for n8n
- [ ] Test webhook working (hello world)
- [ ] Environment variables secured

**Technical Details:**
- Use n8n Cloud (easiest) or Docker self-hosted
- Store API keys in n8n credentials (never in code)
- Configure CORS for iOS app domain

**Estimate:** 30 min

---

### Story 6.2: Auto-Processing Workflow (Feature 1, 4, 5) (1.5 hours)

**As Andrew, I want every fan DM automatically categorized and analyzed so I can prioritize my responses.**

**n8n Workflow Design:**

**Nodes:**
1. **Webhook Trigger** (receives `{ messageText, messageId, senderId }`)
2. **OpenAI Chat Node 1 - Categorization**
   - Model: `gpt-3.5-turbo`
   - Prompt:
   ```
   Categorize this message into one category: fan, business, spam, urgent

   Message: {{messageText}}

   Respond with only one word: fan, business, spam, or urgent
   ```
3. **OpenAI Chat Node 2 - Sentiment Analysis**
   - Model: `gpt-3.5-turbo`
   - Prompt:
   ```
   Analyze the sentiment of this message. Choose one: positive, negative, urgent, neutral

   Message: {{messageText}}

   Respond with only one word.
   ```
4. **IF Node** (check if category == "business")
5. **OpenAI Chat Node 3 - Opportunity Scoring** (only if business)
   - Model: `gpt-4`
   - Prompt:
   ```
   Score this business collaboration opportunity from 0-100 based on:
   - Monetary value potential
   - Brand fit for a tech content creator
   - Legitimacy (not spam)
   - Urgency

   Message: {{messageText}}

   Respond with only a number 0-100 and brief reasoning.
   ```
6. **Firestore Node** (update message document with AI metadata)
7. **Webhook Response** (return `{ category, sentiment, score }`)

**iOS Integration:**
```swift
// In MessageThreadViewModel.swift
func sendMessage(_ text: String) async {
    // 1. Create message locally (optimistic UI)
    let message = MessageEntity(...)
    modelContext.insert(message)

    // 2. Sync to Firebase RTDB
    await realtimeDBService.sendMessage(...)

    // 3. Call n8n auto-processing workflow
    Task {
        let metadata = try await aiService.processMessage(text)

        // 4. Update local message with AI metadata
        message.aiCategory = metadata.category
        message.aiSentiment = metadata.sentiment
        message.aiScore = metadata.score

        try? modelContext.save()
    }
}
```

**UI Changes:**
- Add AI badge component to `MessageBubbleView`
- Show category icon (💬 Fan, 💼 Business, 🚨 Urgent, 🗑️ Spam)
- Show sentiment color (🟢 Positive, 🔴 Negative, 🟡 Urgent)
- Show opportunity score for business messages (💰 Score: 85/100)

**Acceptance Criteria:**
- [ ] n8n workflow deployed and accessible
- [ ] All 3 AI features run in parallel (<2s total)
- [ ] Message metadata saved to Firestore
- [ ] iOS displays AI badges correctly
- [ ] Works for all message types (fan, business, spam, urgent)

**Estimate:** 1.5 hours

---

### Story 6.3: FAQ Auto-Responder (Feature 3) (1.5 hours)

**As a fan, I want instant answers to common questions so I don't have to wait for Andrew.**

**FAQ Library Setup:**

Create 10-15 FAQs in Firestore with embeddings:

```json
{
  "faq_001": {
    "question": "What time do you stream?",
    "answer": "I stream Monday-Friday at 7pm EST on YouTube! See you there 🎮",
    "embedding": [...],
    "category": "schedule",
    "variations": ["when stream", "streaming schedule", "what time"]
  },
  "faq_002": {
    "question": "How can I support you?",
    "answer": "Thanks for asking! You can support through YouTube memberships, Patreon, or just sharing my content. Every bit helps! 🙏",
    "embedding": [...],
    "category": "support"
  }
}
```

**n8n Workflow Design:**

**Nodes:**
1. **Webhook Trigger** (receives `{ messageText, conversationId }`)
2. **OpenAI Embeddings Node**
   - Model: `text-embedding-3-small`
   - Input: `{{messageText}}`
3. **Firestore Vector Search Node**
   - Collection: `faqs`
   - Find nearest embedding match
   - Return top match + similarity score
4. **IF Node** (check if similarity > 0.80)
5. **IF TRUE → Webhook Response** (return FAQ answer)
6. **IF FALSE → Webhook Response** (return `{ isFAQ: false }`)

**iOS Integration:**
```swift
// In MessageThreadViewModel.swift
func receiveMessage(_ message: MessageEntity) async {
    // 1. Display message in UI
    messages.append(message)

    // 2. Check if FAQ (only for fan messages to creator)
    if message.receiverId == CREATOR_ID {
        let faqResponse = try? await aiService.checkFAQ(message.text)

        if faqResponse?.isFAQ == true, let answer = faqResponse?.answer {
            // 3. Auto-send FAQ response
            await sendMessage(answer)

            // 4. Show indicator this was AI-generated
            message.isAIGenerated = true
        }
    }
}
```

**UI Changes:**
- Add `isAIGenerated` badge to AI-sent messages
- Show "🤖 AI Response" label on FAQ answers
- Optional: Allow Andrew to edit AI responses before sending

**Acceptance Criteria:**
- [ ] 10-15 FAQs created with embeddings
- [ ] n8n workflow does vector search correctly
- [ ] Confidence threshold >80% for auto-response
- [ ] iOS auto-sends FAQ answers
- [ ] AI-generated badge shows on auto-responses
- [ ] Andrew can disable auto-response in settings

**Estimate:** 1.5 hours

---

### Story 6.4: Context-Aware Smart Reply Drafting (Feature 2 + Advanced) (2.5 hours)

**As Andrew, I want AI to draft replies in my voice with conversation context so I can respond faster and more authentically.**

**This satisfies TWO requirements:**
- Feature 2: Response drafting in creator's voice
- Advanced AI Capability: Context-Aware Smart Replies (10 points)

**Context Collection:**

Store Andrew's writing style in Firestore:
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

**n8n Workflow Design:**

**Nodes:**
1. **Webhook Trigger** (receives `{ conversationId, messageText, senderId }`)
2. **Firestore Node 1** - Fetch recent messages
   - Query: Get last 20 messages from conversation
   - Provides conversation context
3. **Firestore Node 2** - Fetch creator profile
   - Collection: `creator_profiles/andrew`
   - Get writing style, examples, personality
4. **Function Node** - Build context prompt
   ```javascript
   const recentMessages = $node["Firestore1"].json.messages;
   const profile = $node["Firestore2"].json;
   const fanMessage = $input.item.json.messageText;

   // Build conversation context
   const context = recentMessages.map(m =>
     `${m.senderName}: ${m.text}`
   ).join('\n');

   return {
     systemPrompt: `You are Andrew, a ${profile.personality}

     Your tone: ${profile.tone}

     Example responses you've written:
     ${profile.examples.join('\n')}

     Avoid: ${profile.avoid.join(', ')}

     Recent conversation context:
     ${context}`,

     userPrompt: `The fan just sent: "${fanMessage}"

     Generate 3 reply options:
     1. Short (1 sentence, quick acknowledgment)
     2. Medium (2-3 sentences, friendly and helpful)
     3. Detailed (4-5 sentences, comprehensive response)

     Make each option sound authentic to Andrew's voice. Use conversation context to make replies relevant.

     Format as JSON: { "short": "...", "medium": "...", "detailed": "..." }`
   };
   ```
5. **OpenAI Chat Node**
   - Model: `gpt-4`
   - System message: `{{systemPrompt}}`
   - User message: `{{userPrompt}}`
   - Temperature: 0.7 (creative but consistent)
6. **Code Node** - Parse JSON response
7. **Webhook Response** (return `{ drafts: [short, medium, detailed] }`)

**iOS Integration:**

**New View: `SmartReplyPickerView.swift`**
```swift
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
                    VStack(alignment: .leading) {
                        HStack {
                            Text(draftLabel(index))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(draft.count) chars")
                                .font(.caption2)
                        }
                        Text(draft)
                            .font(.body)
                            .multilineTextAlignment(.leading)
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

**Update `MessageThreadView.swift`:**
```swift
struct MessageThreadView: View {
    @State private var showSmartReplies = false
    @State private var smartReplyDrafts: [String] = []

    var body: some View {
        VStack {
            messageListView

            HStack {
                if isCreator {
                    Button("✨ Draft Reply") {
                        Task {
                            let drafts = try await viewModel.generateSmartReplies()
                            smartReplyDrafts = drafts
                            showSmartReplies = true
                        }
                    }
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
        }
    }
}
```

**In `AIService.swift`:**
```swift
actor AIService {
    func generateSmartReplies(
        conversationId: String,
        messageText: String
    ) async throws -> [String] {
        let url = URL(string: "\(n8nBaseURL)/smart-replies")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "conversationId": conversationId,
            "messageText": messageText
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SmartReplyResponse.self, from: data)

        return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
    }
}
```

**Acceptance Criteria:**
- [ ] n8n workflow fetches conversation context (last 20 messages)
- [ ] Creator profile with style examples stored in Firestore
- [ ] GPT-4 generates 3 distinct reply options
- [ ] iOS shows smart reply picker with 3 options
- [ ] Selecting a draft populates message composer (editable)
- [ ] Response time <8s (meets rubric target)
- [ ] Drafts sound authentic to Andrew's voice
- [ ] Drafts use conversation context (not generic)

**Advanced AI Capability Requirements Met:**
- ✅ Learns user style accurately (from examples + profile)
- ✅ Generates authentic-sounding replies (GPT-4 with style training)
- ✅ Provides 3+ relevant options (short/medium/detailed)
- ✅ Response times meet targets (<8s)
- ✅ Context-aware (uses recent messages)

**Estimate:** 2.5 hours

---

### Story 6.5: iOS AI Service Integration (1.5 hours)

**As a developer, I want a clean AIService layer so all AI features are centralized and testable.**

**Create: `buzzbox/Core/Services/AIService.swift`**

```swift
import Foundation

/// AI service for n8n workflow integration
/// Handles all AI features: categorization, FAQ, sentiment, opportunity scoring, smart replies
@MainActor
final class AIService: ObservableObject {

    // MARK: - Configuration

    private let n8nBaseURL: String

    init(n8nBaseURL: String = ProcessInfo.processInfo.environment["N8N_BASE_URL"] ?? "") {
        self.n8nBaseURL = n8nBaseURL
    }

    // MARK: - Auto-Processing (Features 1, 4, 5)

    struct AIMetadata: Codable {
        let category: MessageCategory
        let sentiment: MessageSentiment
        let score: Int?  // Only for business messages
    }

    enum MessageCategory: String, Codable {
        case fan, business, spam, urgent
    }

    enum MessageSentiment: String, Codable {
        case positive, negative, urgent, neutral
    }

    func processMessage(_ text: String) async throws -> AIMetadata {
        let url = URL(string: "\(n8nBaseURL)/process-message")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        request.timeoutInterval = 5  // 5 second timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.networkError
        }

        return try JSONDecoder().decode(AIMetadata.self, from: data)
    }

    // MARK: - FAQ Auto-Responder (Feature 3)

    struct FAQResponse: Codable {
        let isFAQ: Bool
        let answer: String?
        let confidence: Double?
    }

    func checkFAQ(_ text: String) async throws -> FAQResponse {
        let url = URL(string: "\(n8nBaseURL)/check-faq")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])
        request.timeoutInterval = 3

        let (data, _) = try await URLSession.shared.data(for: request)
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

    func generateSmartReplies(
        conversationId: String,
        messageText: String
    ) async throws -> [String] {
        let url = URL(string: "\(n8nBaseURL)/smart-replies")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "conversationId": conversationId,
            "messageText": messageText
        ]
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 10  // Longer timeout for GPT-4

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SmartReplyResponse.self, from: data)

        return [response.drafts.short, response.drafts.medium, response.drafts.detailed]
    }

    // MARK: - Error Handling

    enum AIServiceError: LocalizedError {
        case networkError
        case invalidResponse
        case timeout

        var errorDescription: String? {
            switch self {
            case .networkError: return "Failed to connect to AI service"
            case .invalidResponse: return "Invalid response from AI service"
            case .timeout: return "AI request timed out"
            }
        }
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
- [ ] AIService created with all 5 features
- [ ] Clean async/await API
- [ ] Proper error handling and timeouts
- [ ] Injectable for testing
- [ ] Environment variable for n8n URL
- [ ] Codable models for all responses

**Estimate:** 1.5 hours

---

### Story 6.6: Message Model Updates for AI Metadata (30 min)

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
        isAIGenerated: Bool = false
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
    }
}
```

**Update Firestore sync to include AI fields:**

```swift
// In FirestoreService.swift - syncMessage()
func syncMessage(_ message: MessageEntity) async throws {
    let data: [String: Any] = [
        "id": message.id,
        "text": message.text,
        "senderID": message.senderID,
        "timestamp": Timestamp(date: message.timestamp),
        // ... other fields

        // AI Metadata
        "aiCategory": message.aiCategory ?? NSNull(),
        "aiSentiment": message.aiSentiment ?? NSNull(),
        "aiOpportunityScore": message.aiOpportunityScore ?? NSNull(),
        "isAIGenerated": message.isAIGenerated,
        "aiProcessedAt": message.aiProcessedAt.map { Timestamp(date: $0) } ?? NSNull()
    ]

    try await db.collection("messages").document(message.id).setData(data)
}
```

**Acceptance Criteria:**
- [ ] AI fields added to MessageEntity
- [ ] SwiftData migration handled (optional fields)
- [ ] Firestore sync includes AI metadata
- [ ] Firebase RTDB includes AI metadata
- [ ] Backward compatible with existing messages

**Estimate:** 30 min

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

**Estimate:** 1.5 hours

---

## ⏱️ Time Breakdown

| Story | Description | Time |
|-------|-------------|------|
| 6.1 | n8n Setup & Configuration | 30 min |
| 6.2 | Auto-Processing Workflow (Features 1, 4, 5) | 1.5 hrs |
| 6.3 | FAQ Auto-Responder (Feature 3) | 1.5 hrs |
| 6.4 | Context-Aware Smart Replies (Feature 2 + Advanced) | 2.5 hrs |
| 6.5 | iOS AI Service Integration | 1.5 hrs |
| 6.6 | Message Model Updates | 30 min |
| 6.7 | AI UI Components | 1.5 hrs |
| **TOTAL** | | **9 hours** |

### Buffer: None needed (conservative estimates)

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

**FAQ Collection:**
```
/faqs/{faqId}
  - question: String
  - answer: String
  - embedding: [Double]  // OpenAI embedding vector
  - category: String
  - variations: [String]
```

**Creator Profile Collection:**
```
/creator_profiles/andrew
  - personality: String
  - tone: String
  - examples: [String]
  - avoid: [String]
  - signature: String
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
- ✅ All AI features respond within latency targets (<2s simple, <8s advanced)

### Technical Requirements
- ✅ 3 n8n workflows deployed and operational
- ✅ AIService integrated into iOS app
- ✅ MessageEntity includes AI metadata fields
- ✅ Firestore has FAQ library with embeddings
- ✅ Creator profile with writing style examples stored
- ✅ All API calls properly secured (API keys in n8n only)

### UX Requirements
- ✅ AI badges visible and color-coded on messages
- ✅ Smart reply picker shows 3 distinct options
- ✅ AI-generated FAQ responses clearly labeled
- ✅ Creator can edit AI drafts before sending
- ✅ Loading states for AI processing
- ✅ Error handling with user-friendly messages

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

### Risk 1: n8n Latency Exceeds Targets
**Impact:** Could lose points for slow response times
**Mitigation:**
- Use GPT-3.5-turbo for simple tasks (categorization, sentiment)
- Reserve GPT-4 only for smart replies
- Run categorization/sentiment/scoring in parallel
- Set aggressive timeouts (5s max)
- Test latency early, switch to Cloud Functions if needed

### Risk 2: n8n Deployment Issues
**Impact:** Could block implementation
**Mitigation:**
- Use n8n Cloud (managed hosting, $20/month)
- Alternative: Docker self-hosted on DigitalOcean ($6/month)
- Have backup plan: Cloud Functions implementation ready
- Test n8n deployment in Story 6.1 (first story)

### Risk 3: OpenAI API Costs
**Impact:** High costs during testing/demo
**Mitigation:**
- Use GPT-3.5-turbo where possible (10x cheaper)
- Cache common FAQ embeddings
- Set rate limits (100 requests/user/hour)
- Monitor usage in OpenAI dashboard
- Budget: $20-30 for entire sprint

### Risk 4: AI Accuracy Too Low
**Impact:** Features work but aren't useful
**Mitigation:**
- Use strong prompts with examples
- Test with real-world fan messages
- Tune confidence thresholds (FAQ: 80%, categorization: 70%)
- Provide manual override for all AI features
- Show confidence scores in UI for transparency

### Risk 5: Context Window Limits
**Impact:** Can't include enough conversation context
**Mitigation:**
- Limit to last 20 messages (sufficient for most conversations)
- Use message summaries if needed (GPT-4 Turbo has 128k context)
- Test with long conversations (100+ messages)
- Fallback to recent context if full history too large

---

## 📦 Implementation Order

### Phase 1: Infrastructure (1 hour)
1. Deploy n8n instance (Cloud or self-hosted)
2. Configure OpenAI API credentials
3. Set up Firestore service account
4. Create FAQ collection with 10-15 FAQs
5. Create creator profile with style examples

### Phase 2: Auto-Processing (2 hours)
6. Build n8n Workflow 1 (categorization + sentiment + scoring)
7. Test workflow with sample messages
8. Integrate AIService.processMessage() in iOS
9. Update MessageEntity with AI fields
10. Add AI badges to MessageBubbleView

### Phase 3: FAQ Auto-Responder (2 hours)
11. Generate embeddings for FAQ library
12. Build n8n Workflow 2 (FAQ matching)
13. Integrate AIService.checkFAQ() in iOS
14. Add auto-response logic to message receiving
15. Add AI-generated badge to UI

### Phase 4: Context-Aware Smart Replies (3 hours)
16. Build n8n Workflow 3 (smart reply generation)
17. Test with conversation context fetching
18. Create SmartReplyPickerView UI component
19. Integrate "Draft Reply" button
20. Test end-to-end with real conversations

### Phase 5: Polish & Testing (1 hour)
21. Test all 5 AI features end-to-end
22. Verify latency meets targets
23. Test error handling (network failures, timeouts)
24. Polish UI animations and loading states
25. Update documentation

**Total: 9 hours**

---

## 📚 References

- **Project Brief:** `docs/project-brief.md` (Content Creator persona, 5 required features)
- **Scoring Rubric:** `docs/scoring.md` (Section 3: 30 pts AI + 10 pts Advanced)
- **Tech Stack:** `docs/architecture/technology-stack.md` (OpenAI, Firestore, n8n)
- **Epic 5:** Single-Creator Platform (provides inbox for AI to manage)

---

## 🎬 Next Steps

**After Epic 6 Completion:**
1. ✅ All 5 AI features implemented and working
2. ✅ Advanced AI Capability (Context-Aware Smart Replies) complete
3. ✅ **40 points secured** (AI Features + Advanced)
4. 🚀 **Epic 7: Documentation & Demo Video** (avoid -30 points in penalties)
5. 🚀 **Epic 8: Testing & Polish** (ensure B+ or A- grade)

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
**Risk Level:** Low-Medium (n8n hosting main risk, mitigated with Cloud option)
**Strategic Value:** CRITICAL - 40% of total grade

**Recommendation: START EPIC 6 IMMEDIATELY AFTER EPIC 5. This is 40 points waiting to be claimed.**
