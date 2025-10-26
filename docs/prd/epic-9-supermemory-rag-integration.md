# Epic 9: Supermemory RAG Integration

**Phase:** Post-Epic 6 (AI Enhancement)
**Priority:** P1 (High - AI Quality Improvement)
**Estimated Time:** 12-16 hours
**Epic Owner:** Product Owner
**Dependencies:** Epic 6 (AI-Powered Creator Inbox)
**Risk Level:** Low-Medium (External API dependency, graceful degradation required)

---

## 📋 Strategic Context

### Why This Epic Exists

**Current State:** After Epic 6, BuzzBox has AI-powered auto-replies using OpenAI GPT-4:
- ✅ Smart reply drafting in Andrew's voice
- ✅ FAQ auto-responder
- ✅ Context-aware replies using conversation history
- ⚠️ **Problem:** AI only knows conversation context from current thread (last 20 messages)
- ⚠️ **Problem:** AI cannot learn from Andrew's actual replies over time
- ⚠️ **Problem:** Same questions get different answers (no knowledge base)

**The Gap:** Andrew often answers similar questions from multiple fans. Current AI:
- Doesn't remember how Andrew answered similar questions before
- Can't leverage Andrew's actual writing style from past replies
- Generates generic responses instead of learning from real examples
- Requires manual FAQ creation (doesn't auto-learn from conversations)

**Real-World Example:**
```
Fan 1 (Week 1): "When is your next livestream?"
Andrew replies: "Next livestream is Saturday at 3pm EST! I'll be coding a SwiftUI app 🎉"

Fan 2 (Week 2): "When do you stream?"
AI Draft (Current): "I stream regularly! Check my schedule for details."
AI Draft (With Supermemory): "Next livestream is Saturday at 3pm EST! I'll be coding a SwiftUI app 🎉"
                               ☝️ Learned from Andrew's actual reply
```

**Solution:** Integrate Supermemory API to create a RAG (Retrieval-Augmented Generation) system:
- 🎯 Store every manual reply Andrew sends as a Q&A pair in Supermemory
- 🎯 Search Supermemory before generating AI drafts
- 🎯 Include top 3 relevant past Q&As in the AI prompt
- 🎯 AI generates replies that match Andrew's actual style and content

**Business Value:**
- Better AI replies = Andrew saves more time
- Consistent answers across similar questions
- AI quality improves automatically over time (no manual FAQ updates)
- Fans get more accurate, personalized responses

---

## 🎯 What This Epic Delivers

### User Experience

**For Andrew (The Creator):**
- ✅ **Automatic Learning:** Every manual reply is stored in Supermemory (invisible, automatic)
- ✅ **Better AI Drafts:** Smart replies leverage similar past conversations
- ✅ **Consistent Answers:** Same questions get consistent replies based on past answers
- ✅ **Progressive Improvement:** AI quality improves over time as knowledge base grows
- ✅ **Zero Maintenance:** No manual FAQ updates needed (auto-learns from replies)

**For Fans:**
- ✅ More accurate AI responses (when Andrew uses them)
- ✅ Consistent information across conversations
- ✅ Answers that sound authentically like Andrew

**What's New:**
- 🆕 Supermemory API integration service (`SupermemoryService.swift`)
- 🆕 Automatic memory storage on Andrew's manual replies
- 🆕 Memory search before AI draft generation
- 🆕 Context-enhanced prompts with past Q&As
- 🆕 Supermemory API key management (Keychain)
- 🆕 Offline queue for memory operations
- 🆕 Memory stats in Profile (optional: "AI has learned from X conversations")

---

## 🏗️ Architecture Overview

### RAG (Retrieval-Augmented Generation) Pattern

```
┌─────────────────────────────────────────────────────────────┐
│ User Flow: Andrew Sends Manual Reply                       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ MessageThreadViewModel.sendMessage()     │
   └──────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ Extract: Fan Question + Andrew Answer    │
   │ Format: "Q: {question}\nA: {answer}"     │
   └──────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ SupermemoryService.addMemory()           │
   │ POST v2.api.supermemory.ai/add           │
   │ Headers: x-api-key                       │
   └──────────────────────────────────────────┘
                          │
                          ▼
           Supermemory Vector Database
        (Semantic search enabled by default)


┌─────────────────────────────────────────────────────────────┐
│ User Flow: AI Drafts Reply                                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ AIService.generateSmartReply()           │
   └──────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ SupermemoryService.searchMemories()      │
   │ Query: Fan's message                     │
   │ Limit: 3 most relevant                   │
   └──────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ Extract top 3 Q&A pairs                  │
   │ Format for prompt context                │
   └──────────────────────────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────┐
   │ OpenAI GPT-4 with Enhanced Prompt:       │
   │                                           │
   │ System: You are Andrew's assistant       │
   │                                           │
   │ Context: Here are similar past convos:   │
   │ Q: When do you stream?                   │
   │ A: Saturday 3pm EST!                     │
   │                                           │
   │ Q: ...                                   │
   │ A: ...                                   │
   │                                           │
   │ User: {current fan message}              │
   └──────────────────────────────────────────┘
                          │
                          ▼
           AI-Generated Reply Draft
      (Informed by past conversations)
```

### Technology Stack

**Swift/iOS Side:**
- `URLSession` for HTTP requests (native, no SDK needed)
- `Keychain` for secure API key storage
- `async/await` for asynchronous operations
- SwiftData for offline queue (reuse existing sync patterns)

**Backend Side:**
- Supermemory API (`v2.api.supermemory.ai`)
- RESTful JSON API
- Header-based authentication (`x-api-key`)

**Why Supermemory Instead of Building Custom RAG:**
- ✅ Production-ready semantic search (no vector DB setup)
- ✅ Free tier available (10,000 memories/month)
- ✅ Smart chunking & indexing handled automatically
- ✅ No maintenance overhead (managed service)
- ✅ Simple REST API (vs complex embeddings + vector DB)
- ✅ Decay/recency built-in (recent memories prioritized)

**Trade-offs:**
- ⚠️ External API dependency (requires internet)
- ⚠️ API costs at scale (free tier: 10K memories/month)
- ⚠️ Latency added (~500ms-1s for search)
- ✅ Mitigation: Graceful degradation (works without Supermemory)

---

## 📊 High-Level Implementation Overview

### 1. Supermemory API Service (Swift)

**File:** `buzzbox/Core/Services/SupermemoryService.swift`

**Key Methods:**
```swift
@MainActor
final class SupermemoryService: ObservableObject {
    static let shared = SupermemoryService()

    /// Add a memory (Q&A pair) to Supermemory
    /// - Fire-and-forget pattern (don't block UI)
    /// - Queue if offline, sync when online
    func addMemory(content: String, metadata: [String: String]?) async throws

    /// Search memories by semantic similarity
    /// - Returns top N most relevant memories
    /// - Timeout: 2 seconds (fallback to no memories)
    func searchMemories(query: String, limit: Int = 3) async throws -> [Memory]

    /// Check if Supermemory is enabled and configured
    var isEnabled: Bool { get }
}
```

**API Endpoints:**
- **Add Memory:** `POST https://v2.api.supermemory.ai/add`
- **Search Memories:** `GET/POST https://v2.api.supermemory.ai/search` (TBD from docs)

**Authentication:**
- Header: `x-api-key: YOUR_API_KEY`
- Stored in Keychain: `KeychainHelper.save(key: "supermemory_api_key", value: apiKey)`

---

### 2. Memory Storage on Manual Replies

**Trigger:** Andrew sends a message (`senderID == CREATOR_UID`)

**Logic:**
```swift
// In MessageThreadViewModel.sendMessage()
if AuthService.shared.isCreator {
    // Extract context
    let fanMessage = getLastFanMessage() // Last message from fan
    let andrewReply = messageText

    // Format Q&A pair
    let memory = """
    Q: \(fanMessage.text)
    A: \(andrewReply)
    """

    // Store in Supermemory (fire-and-forget)
    Task.detached {
        try? await SupermemoryService.shared.addMemory(
            content: memory,
            metadata: [
                "conversationID": conversationID,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "category": conversation.aiCategory ?? "unknown"
            ]
        )
    }
}
```

**Edge Cases Handled:**
1. **Offline:** Queue in SwiftData, sync when online
2. **API Failure:** Log error, don't block message sending
3. **No Fan Context:** Skip memory storage (can't create Q&A without question)
4. **Duplicate Memories:** Supermemory handles deduplication via content hash
5. **Rate Limiting:** Respect API limits, queue excess memories

---

### 3. Context-Enhanced AI Drafts

**Updated Logic in `AIService.generateSmartReply()`:**

```swift
func generateSmartReply(for message: Message, in conversation: Conversation) async throws -> [String] {
    // Step 1: Search Supermemory for relevant past conversations
    var contextMemories: [Memory] = []

    if SupermemoryService.shared.isEnabled {
        do {
            contextMemories = try await SupermemoryService.shared.searchMemories(
                query: message.text,
                limit: 3
            )
        } catch {
            // Graceful degradation: Continue without memories
            print("Supermemory search failed: \(error)")
        }
    }

    // Step 2: Build enhanced prompt with past Q&As
    var systemPrompt = """
    You are Andrew's AI assistant. Generate a reply in his voice.

    Andrew's Style: Friendly, encouraging, tech-focused, uses emojis occasionally.
    """

    if !contextMemories.isEmpty {
        systemPrompt += """

        Here are similar past conversations for context:

        \(contextMemories.map { $0.content }.joined(separator: "\n\n"))
        """
    }

    // Step 3: Generate reply with OpenAI (existing logic)
    let response = try await openAI.chat.completions.create(
        model: "gpt-4o-mini",
        messages: [
            .system(content: systemPrompt),
            .user(content: message.text)
        ],
        temperature: 0.7,
        maxTokens: 200
    )

    return [response.choices.first?.message.content ?? ""]
}
```

**Prompt Example with Memories:**
```
System: You are Andrew's AI assistant. Generate a reply in his voice.

Andrew's Style: Friendly, encouraging, tech-focused, uses emojis occasionally.

Here are similar past conversations for context:

Q: When is your next livestream?
A: Next livestream is Saturday at 3pm EST! I'll be coding a SwiftUI app 🎉

Q: What tools do you use for iOS dev?
A: I use Xcode, SwiftUI, and Firebase mostly. Claude Code for AI assistance!

Q: Can you review my app idea?
A: I'd love to hear about it! DM me the details and I'll take a look when I can.

User: hey when are you streaming next?