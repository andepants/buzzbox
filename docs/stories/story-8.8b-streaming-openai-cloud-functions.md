# Story 8.8b: Streaming OpenAI Responses (Cloud Functions)

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 3 - Advanced Polish (OPTIONAL)
**Priority:** P2 (Nice-to-have - backend for streaming)
**Effort:** 1 hour
**Risk:** MEDIUM - SSE implementation complexity
**Status:** Ready for Development

---

## Goal

Implement Server-Sent Events (SSE) endpoint in Cloud Functions to stream OpenAI responses back to iOS client in real-time.

---

## User Story

**As** the BuzzBox backend,
**I want** to stream OpenAI responses via Server-Sent Events,
**So that** iOS clients can display smart replies as they're generated.

---

## Dependencies

- ⚠️ **Story 8.8a:** Streaming OpenAI iOS Client (must be implemented together)
- ✅ Existing Cloud Functions infrastructure
- ✅ OpenAI SDK with streaming support

---

## Implementation

### Cloud Function: generateSmartReplyStreaming

Update `functions/src/index.ts`:

```typescript
import * as functions from 'firebase-functions';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export const generateSmartReplyStreaming = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .https
  .onRequest(async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    try {
      const { conversationId, messageText, replyType } = req.body;

      // Validate input
      if (!conversationId || !messageText || !replyType) {
        res.write(`data: ${JSON.stringify({ error: 'Missing required fields' })}\n\n`);
        res.end();
        return;
      }

      // Build prompt (reuse existing logic)
      const prompt = buildSmartReplyPrompt(messageText, replyType);

      // Create streaming OpenAI request
      const stream = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant generating smart reply suggestions.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        stream: true,
        max_tokens: 150,
        temperature: 0.7,
      });

      let totalTokens = 0;

      // Stream chunks to client
      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';

        if (content) {
          res.write(`data: ${JSON.stringify({ content })}\n\n`);
          totalTokens += estimateTokens(content);
        }

        // Check for client disconnect
        if (res.writableEnded) {
          console.log('🔌 Client disconnected, stopping stream');
          break;
        }
      }

      // Send completion marker
      res.write('data: [DONE]\n\n');
      res.end();

      // Log token usage for cost tracking
      console.log(`✅ Streaming completed: ${totalTokens} tokens (approx)`);

    } catch (error: any) {
      console.error('❌ Streaming error:', error);

      // Send error event via SSE
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
      res.end();
    }
  });

function buildSmartReplyPrompt(messageText: string, replyType: string): string {
  // Reuse existing prompt building logic from non-streaming function
  const prompts: { [key: string]: string } = {
    friendly: `Generate a friendly reply to: "${messageText}"`,
    professional: `Generate a professional reply to: "${messageText}"`,
    brief: `Generate a brief reply to: "${messageText}"`,
  };

  return prompts[replyType] || prompts.friendly;
}

function estimateTokens(text: string): number {
  // Rough estimate: ~4 characters per token
  return Math.ceil(text.length / 4);
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Cloud Function streams OpenAI responses via SSE
- ✅ iOS client receives chunks in real-time
- ✅ Error handling for OpenAI API failures
- ✅ Timeout protection (max 60 seconds)
- ✅ CORS headers set correctly

### SSE Protocol Requirements
- ✅ Content-Type: text/event-stream
- ✅ Cache-Control: no-cache
- ✅ Connection: keep-alive
- ✅ Data format: `data: {"content": "..."}\n\n`
- ✅ Completion marker: `data: [DONE]\n\n`

### Logging Requirements
- ✅ Log token usage for cost tracking
- ✅ Log errors with context
- ✅ Log client disconnections

---

## Edge Cases & Error Handling

### OpenAI Stream Hang
- ✅ **Behavior:** 60-second timeout terminates function
- ✅ **Implementation:** `timeoutSeconds: 60` in function config

### Client Disconnect
- ✅ **Behavior:** Detects closed connection, stops streaming
- ✅ **Implementation:** Check `res.writableEnded` in loop

### OpenAI API Error
- ✅ **Behavior:** Returns error event via SSE
- ✅ **Implementation:** Catch block sends error JSON

### Cost Monitoring
- ✅ **Behavior:** Logs token usage for cost tracking
- ✅ **Implementation:** Estimate tokens from content length

### CORS Preflight
- ✅ **Behavior:** Handles OPTIONS request correctly
- ✅ **Implementation:** Return 204 for OPTIONS

---

## Files to Modify

### Cloud Functions
- `functions/src/index.ts`
  - Add `generateSmartReplyStreaming` function
  - Add SSE headers
  - Stream OpenAI chunks
  - Handle client disconnect
  - Log token usage

- `functions/package.json`
  - Ensure OpenAI SDK version supports streaming (>= 4.0.0)

---

## Technical Notes

### Server-Sent Events (SSE) Protocol

SSE format:
```
data: {"content": "Hello"}

data: {"content": " world"}

data: [DONE]

```

Each event must end with double newline (`\n\n`).

### OpenAI Streaming API

Use OpenAI streaming:
```typescript
const stream = await openai.chat.completions.create({
  model: 'gpt-4o-mini',
  messages: [...],
  stream: true,
});

for await (const chunk of stream) {
  const content = chunk.choices[0]?.delta?.content || '';
  // Send via SSE
}
```

### Client Disconnect Detection

Check if response is closed:
```typescript
if (res.writableEnded) {
  console.log('Client disconnected');
  break;
}
```

### Cost Tracking

Estimate tokens for logging:
```typescript
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4); // ~4 chars per token
}
```

---

## Testing Checklist

### Local Testing (Firebase Emulator)
- [ ] Start Firebase emulator: `firebase emulators:start`
- [ ] Test streaming endpoint with curl:
  ```bash
  curl -N -X POST http://localhost:5001/YOUR_PROJECT/us-central1/generateSmartReplyStreaming \
    -H "Content-Type: application/json" \
    -d '{"conversationId":"test","messageText":"Hello","replyType":"friendly"}'
  ```
- [ ] Verify SSE format in response
- [ ] Verify [DONE] marker at end

### Production Testing
- [ ] Deploy function: `firebase deploy --only functions:generateSmartReplyStreaming`
- [ ] Test from iOS app
- [ ] Verify streaming works
- [ ] Check Cloud Functions logs for token usage

### Edge Case Testing
- [ ] Invalid input → error event sent
- [ ] OpenAI API error → error event sent
- [ ] Client disconnect mid-stream → logs disconnect
- [ ] Timeout (60s) → function terminates gracefully

### Cost Testing
- [ ] Generate 10 streaming replies
- [ ] Check logs for token usage
- [ ] Estimate monthly costs based on usage

---

## OpenAI SDK Version

Ensure `functions/package.json`:

```json
{
  "dependencies": {
    "openai": "^4.0.0",
    "firebase-functions": "^4.0.0",
    "firebase-admin": "^12.0.0"
  }
}
```

Run `npm install` in `functions/` directory.

---

## Deployment Commands

```bash
# Test locally
cd functions
npm run build
firebase emulators:start

# Deploy to production
firebase deploy --only functions:generateSmartReplyStreaming

# View logs
firebase functions:log --only generateSmartReplyStreaming
```

---

## Definition of Done

- ✅ `generateSmartReplyStreaming` function created
- ✅ SSE headers set correctly
- ✅ OpenAI streaming implemented
- ✅ Client disconnect detection working
- ✅ Error handling via SSE events
- ✅ Token usage logging implemented
- ✅ CORS headers configured
- ✅ Timeout protection (60s) configured
- ✅ Tested on Firebase emulator
- ✅ Tested in production with iOS app
- ✅ Logs show token usage
- ✅ No OpenAI API errors

---

## Cost Estimation

**Assumptions:**
- Average reply: 30 tokens (input) + 50 tokens (output) = 80 tokens
- GPT-4o-mini pricing: $0.15 per 1M input tokens, $0.60 per 1M output tokens
- 100 streaming replies/day = 3,000 replies/month

**Monthly cost:**
- Input: 3,000 × 30 = 90,000 tokens = $0.01
- Output: 3,000 × 50 = 150,000 tokens = $0.09
- **Total: ~$0.10/month**

Streaming has **no additional cost** compared to non-streaming.

---

## Related Stories

- **Story 8.8a:** Streaming OpenAI iOS Client (frontend counterpart)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 572-633)
