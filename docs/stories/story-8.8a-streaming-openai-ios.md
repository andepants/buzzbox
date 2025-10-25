# Story 8.8a: Streaming OpenAI Responses (iOS Client)

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 3 - Advanced Polish (OPTIONAL)
**Priority:** P2 (Nice-to-have - impressive demo feature)
**Effort:** 2 hours
**Risk:** HIGH - Complex async state management
**Status:** Ready for Development

---

## Goal

Enable iOS client to receive and display streaming AI responses in real-time, making smart replies feel instant and engaging.

---

## User Story

**As** Andrew (The Creator),
**I want** to see smart reply suggestions appear character-by-character as they're generated,
**So that** the app feels fast and I can start reading suggestions immediately.

---

## Dependencies

- ⚠️ **Story 8.8b:** Streaming OpenAI Cloud Functions (must be implemented together)
- ✅ Existing AIService and FloatingFABView
- ✅ Epic 6: Smart reply generation infrastructure

---

## Implementation

### AIService Streaming Method

Update `buzzbox/Core/Services/AIService.swift`:

```swift
@MainActor
class AIService {
    /// Generate streaming smart reply with real-time chunks
    func generateSingleSmartReplyStreaming(
        conversationId: String,
        messageText: String,
        replyType: String,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: "\(cloudFunctionsBaseURL)/generateSmartReplyStreaming") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "conversationId": conversationId,
            "messageText": messageText,
            "replyType": replyType
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Create URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)

        // Stream response
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }

        var fullResponse = ""
        var buffer = ""

        for try await line in asyncBytes.lines {
            // Server-Sent Events format: "data: {content}"
            guard line.hasPrefix("data: ") else { continue }

            let data = line.dropFirst(6) // Remove "data: " prefix

            if data == "[DONE]" {
                break
            }

            // Parse JSON chunk
            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let content = json["content"] as? String {

                // Buffer chunks for UTF-8 validation
                buffer += content

                // Validate UTF-8 before yielding
                if buffer.isValidUTF8 {
                    fullResponse += buffer
                    onChunk(buffer)
                    buffer = ""
                }
            }
        }

        // Yield any remaining buffer
        if !buffer.isEmpty {
            fullResponse += buffer
            onChunk(buffer)
        }

        return fullResponse
    }

    /// Fallback to non-streaming if error
    private func fallbackToNonStreaming(
        conversationId: String,
        messageText: String,
        replyType: String
    ) async throws -> String {
        // Call existing non-streaming method
        return try await generateSingleSmartReply(
            conversationId: conversationId,
            messageText: messageText,
            replyType: replyType
        )
    }
}

extension String {
    var isValidUTF8: Bool {
        self.utf8.withContiguousStorageIfAvailable { bytes in
            String(decoding: bytes, as: UTF8.self) == self
        } ?? false
    }
}
```

### FloatingFABView Streaming UI

Update `buzzbox/Core/Views/Components/FloatingFABView.swift`:

```swift
struct FloatingFABView: View {
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Error>?

    var body: some View {
        VStack {
            if isExpanded {
                smartReplyOptions
            }

            fabButton
        }
    }

    private var smartReplyOptions: some View {
        VStack(spacing: 12) {
            ForEach(SmartReplyType.allCases, id: \.self) { replyType in
                Button {
                    generateStreamingReply(type: replyType)
                } label: {
                    if isStreaming {
                        streamingReplyView
                    } else {
                        staticReplyButton(type: replyType)
                    }
                }
                .disabled(isStreaming)
            }
        }
    }

    private var streamingReplyView: some View {
        HStack {
            Text(streamingText)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Spacer()

            ProgressView()
                .scaleEffect(0.8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    func generateStreamingReply(type: SmartReplyType) {
        isStreaming = true
        streamingText = ""

        // Cancel previous stream
        streamingTask?.cancel()

        streamingTask = Task {
            do {
                let fullReply = try await aiService.generateSingleSmartReplyStreaming(
                    conversationId: conversation.id,
                    messageText: lastMessage.text,
                    replyType: type.rawValue
                ) { chunk in
                    // Update UI with each chunk
                    streamingText += chunk
                    HapticFeedback.selection()
                }

                // Stream complete
                isStreaming = false
                selectedReply = fullReply

            } catch {
                print("❌ Streaming failed, falling back: \(error)")

                // Fallback to non-streaming
                let reply = try await aiService.generateSingleSmartReply(
                    conversationId: conversation.id,
                    messageText: lastMessage.text,
                    replyType: type.rawValue
                )

                streamingText = reply
                selectedReply = reply
                isStreaming = false
            }
        }
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        isStreaming = false
        streamingText = ""
    }
}
```

### Lifecycle Management

Handle view dismissal:

```swift
.onDisappear {
    cancelStreaming()
}

.task {
    // Auto-cancel on backgrounding
    for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
        cancelStreaming()
    }
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Smart replies stream character-by-character
- ✅ Typing indicator shows while streaming
- ✅ User can cancel mid-stream (view dismissal)
- ✅ Graceful fallback to non-streaming if error
- ✅ Streaming feels fast (<100ms per chunk)

### Visual Requirements
- ✅ Streaming text appears smoothly
- ✅ Progress indicator shown during streaming
- ✅ Other FAB buttons disabled while streaming

### Performance Requirements
- ✅ No UI lag during streaming
- ✅ UTF-8 validation prevents garbled text
- ✅ Timeout after 30 seconds

---

## Edge Cases & Error Handling

### Connection Drop
- ✅ **Behavior:** Falls back to non-streaming API on network error
- ✅ **Implementation:** Try-catch with fallback method

### App Backgrounding
- ✅ **Behavior:** Cancels stream when app goes to background
- ✅ **Implementation:** Listen to `UIApplication.didEnterBackgroundNotification`

### Concurrent Request Prevention
- ✅ **Behavior:** Disables FAB buttons while streaming (only 1 stream at a time)
- ✅ **Implementation:** `isStreaming` state disables buttons

### Timeout Protection
- ✅ **Behavior:** 30-second timeout falls back to non-streaming
- ✅ **Implementation:** URLSession config with `timeoutIntervalForRequest = 30`

### UTF-8 Validation
- ✅ **Behavior:** Buffers chunks until valid UTF-8 (no garbled text)
- ✅ **Implementation:** `String.isValidUTF8` extension

### Cache Integration
- ✅ **Behavior:** Caches final result after streaming completes
- ✅ **Implementation:** Use existing cache system from Story 6.10

### User Cancellation
- ✅ **Behavior:** Stream task cancelled when FAB dismissed
- ✅ **Implementation:** `.onDisappear { cancelStreaming() }`

---

## Files to Modify

### Primary Files
- `buzzbox/Core/Services/AIService.swift`
  - Add `generateSingleSmartReplyStreaming()` method
  - Add SSE parsing logic
  - Add UTF-8 validation
  - Add timeout handling
  - Add fallback logic

- `buzzbox/Core/Views/Components/FloatingFABView.swift`
  - Add streaming state (`isStreaming`, `streamingText`)
  - Add streaming UI view
  - Add stream cancellation logic
  - Add background detection
  - Disable buttons during streaming

---

## Technical Notes

### Server-Sent Events (SSE) Protocol

Parse SSE format:
```
data: {"content": "Hello"}

data: {"content": " world"}

data: [DONE]
```

### URLSession Streaming

Use `bytes(for:)` API:
```swift
let (asyncBytes, response) = try await session.bytes(for: request)

for try await line in asyncBytes.lines {
    // Process each line
}
```

### UTF-8 Buffering

Prevent garbled text from partial UTF-8 sequences:
```swift
var buffer = ""
buffer += chunk

if buffer.isValidUTF8 {
    onChunk(buffer)
    buffer = ""
}
```

### Task Cancellation

Clean up properly:
```swift
streamingTask?.cancel()
```

---

## Testing Checklist

### Functional Testing
- [ ] Generate smart reply → text streams character-by-character
- [ ] Progress indicator shows during streaming
- [ ] Streaming completes → full text displayed
- [ ] Tap different reply type → cancels previous stream
- [ ] Network error → fallback to non-streaming works

### Edge Case Testing
- [ ] Dismiss FAB while streaming → stream cancels
- [ ] Background app while streaming → stream cancels
- [ ] Slow connection → timeout after 30s → fallback
- [ ] Invalid UTF-8 chunk → buffered until valid
- [ ] Rapid stream requests → previous cancelled

### Performance Testing
- [ ] Streaming feels fast (<100ms per chunk)
- [ ] No UI lag during streaming
- [ ] Memory stable (no leaks from cancelled tasks)

---

## Definition of Done

- ✅ `generateSingleSmartReplyStreaming()` implemented
- ✅ SSE parsing working correctly
- ✅ Streaming UI implemented in FloatingFABView
- ✅ UTF-8 validation prevents garbled text
- ✅ Timeout protection (30s) implemented
- ✅ Fallback to non-streaming on error
- ✅ Task cancellation on view dismissal
- ✅ Task cancellation on backgrounding
- ✅ Concurrent stream prevention
- ✅ Cache integration working
- ✅ No memory leaks
- ✅ Streaming feels fast and responsive

---

## Related Stories

- **Story 8.8b:** Streaming OpenAI Cloud Functions (backend counterpart)
- **Story 8.10:** Enhanced Haptics (haptic on chunk receive)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 522-569)
