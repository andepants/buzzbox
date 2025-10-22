# Supermemory Integration Guide - Sorted

**Version:** 1.0
**Last Updated:** October 20, 2025
**Purpose:** Complete Supermemory API integration for RAG-powered conversation context

---

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication](#2-authentication)
3. [Storing Conversations](#3-storing-conversations)
4. [RAG Queries for Context Retrieval](#4-rag-queries-for-context-retrieval)
5. [Error Handling & Retry Strategies](#5-error-handling--retry-strategies)
6. [Implementation Examples](#6-implementation-examples)
7. [Privacy & Data Management](#7-privacy--data-management)

---

## 1. Overview

### 1.1 What is Supermemory?

Supermemory is a universal memory API that provides long-term conversation storage and RAG (Retrieval-Augmented Generation) capabilities. It enables Sorted to:

- **Store** all conversation history for long-term memory
- **Retrieve** relevant context when drafting AI responses
- **Search** past conversations using semantic similarity
- **Personalize** AI responses based on creator's communication patterns

### 1.2 Why Supermemory for Sorted?

| Feature | Without Supermemory | With Supermemory |
|---------|-------------------|------------------|
| **Context Window** | Limited to recent messages | Unlimited conversation history |
| **Personalization** | Generic AI responses | Responses matching creator's voice |
| **Context Recall** | No memory of past conversations | References relevant past interactions |
| **Response Quality** | One-size-fits-all | Context-aware and personalized |

### 1.3 Architecture Integration

```
iOS App → Firebase Cloud Functions → Supermemory API
  ↓                                        ↓
SwiftData                             Vector DB Storage
(Local Cache)                         (Long-term Memory)
```

**Flow:**
1. User sends/receives messages → Stored in SwiftData locally
2. Background sync → Messages sent to Firestore
3. Cloud Function → Stores messages in Supermemory for RAG
4. When drafting reply → Cloud Function queries Supermemory for context
5. AI uses context → Generates personalized response

---

## 2. Authentication

### 2.1 API Key Authentication

Supermemory uses Bearer token authentication with API keys.

**Authentication Header:**
```
Authorization: Bearer YOUR_SUPERMEMORY_API_KEY
```

**Base URL:**
```
https://api.supermemory.ai/v3
```

### 2.2 Getting an API Key

1. Sign up at [app.supermemory.ai](https://app.supermemory.ai)
2. Navigate to Settings → API Keys
3. Create new API key
4. Store securely in Cloud Functions environment variables

### 2.3 Cloud Functions Configuration

**Set API key in Cloud Functions:**

```bash
# Set Supermemory API key
firebase functions:config:set supermemory.api_key="sm_xxxxxxxxxxxxxxxxxxxx"

# Verify configuration
firebase functions:config:get
```

**Access in Cloud Functions code:**

```javascript
// index.js - Cloud Functions

const functions = require('firebase-functions');
const axios = require('axios');

// Supermemory API configuration
const SUPERMEMORY_API_KEY = functions.config().supermemory.api_key;
const SUPERMEMORY_BASE_URL = 'https://api.supermemory.ai/v3';

// Create axios instance with authentication
const supermemoryClient = axios.create({
  baseURL: SUPERMEMORY_BASE_URL,
  headers: {
    'Authorization': `Bearer ${SUPERMEMORY_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

// Test connection
async function testSupermemoryConnection() {
  try {
    const response = await supermemoryClient.get('/health');
    console.log('✅ Supermemory connected:', response.data);
    return true;
  } catch (error) {
    console.error('❌ Supermemory connection failed:', error.message);
    return false;
  }
}
```

### 2.4 Swift Implementation (iOS Direct Access)

**Note:** For security, iOS app should NOT access Supermemory directly. All requests should go through Cloud Functions to protect API keys.

However, for reference, here's how direct access would work:

```swift
/// SupermemoryService.swift
///
/// ⚠️ SECURITY WARNING: This is for reference only.
/// In production, use Cloud Functions to protect API keys.
///
/// Created: 2025-10-20

import Foundation

actor SupermemoryService {
    // MARK: - Configuration

    private let apiKey: String
    private let baseURL = "https://api.supermemory.ai/v3"

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Request Builder

    private func createRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) -> URLRequest {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: - Example Usage (NOT RECOMMENDED FOR PRODUCTION)

    func addMemory(content: String, metadata: [String: Any]?) async throws {
        let payload: [String: Any] = [
            "content": content,
            "metadata": metadata ?? [:],
            "containerTags": ["sorted", "conversations"]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let request = createRequest(endpoint: "/documents", method: "POST", body: jsonData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupermemoryError.requestFailed
        }

        print("✅ Memory added successfully")
    }
}

enum SupermemoryError: Error {
    case requestFailed
    case invalidResponse
    case unauthorized
}
```

---

## 3. Storing Conversations

### 3.1 Storage Strategy

**When to Store:**
- After every 10 messages in a conversation
- When conversation is archived or marked complete
- On significant conversation milestones

**What to Store:**
```javascript
{
  "content": "Full message text with context",
  "metadata": {
    "conversationID": "conv-123",
    "senderID": "user-456",
    "category": "business",
    "sentiment": "positive",
    "timestamp": "2025-10-20T12:00:00Z"
  },
  "containerTags": ["user-creator-id", "sorted", "conversations"]
}
```

### 3.2 Cloud Function: Store Message

```javascript
/// storeConversationToSupermemory.js
///
/// Cloud Function to store messages in Supermemory for RAG context.
/// Triggered after message creation in Firestore.
///
/// Created: 2025-10-20

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

const SUPERMEMORY_API_KEY = functions.config().supermemory.api_key;
const SUPERMEMORY_BASE_URL = 'https://api.supermemory.ai/v3';

const supermemoryClient = axios.create({
  baseURL: SUPERMEMORY_BASE_URL,
  headers: {
    'Authorization': `Bearer ${SUPERMEMORY_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

/**
 * Store message in Supermemory when created in Firestore
 */
exports.storeMessageToSupermemory = functions.firestore
  .document('conversations/{conversationID}/messages/{messageID}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const { conversationID, messageID } = context.params;

    try {
      // Build Supermemory document
      const supermemoryDoc = {
        customId: messageID, // Use Firestore message ID
        content: buildMessageContent(message),
        metadata: {
          conversationID: conversationID,
          senderID: message.senderID,
          category: message.metadata?.category || 'uncategorized',
          sentiment: message.metadata?.sentiment?.type || 'neutral',
          timestamp: message.createdAt.toDate().toISOString(),
          platform: 'sorted'
        },
        containerTags: [
          message.senderID, // Tag with sender for user-specific queries
          conversationID,   // Tag with conversation for thread queries
          'sorted'       // Platform tag
        ]
      };

      // Store in Supermemory
      const response = await supermemoryClient.post('/documents', supermemoryDoc);

      // Store Supermemory ID back in Firestore
      await snapshot.ref.update({
        supermemoryID: response.data.id
      });

      console.log(`✅ Stored message ${messageID} in Supermemory:`, response.data.id);

      return { success: true, supermemoryID: response.data.id };

    } catch (error) {
      console.error(`❌ Failed to store message in Supermemory:`, error.message);

      // Don't fail the function - Supermemory is optional
      return { success: false, error: error.message };
    }
  });

/**
 * Build rich content for Supermemory storage
 * Includes message text, sender info, and conversation context
 */
function buildMessageContent(message) {
  // Format: "Sender: Message text [Category: X] [Sentiment: Y]"
  let content = `${message.senderID}: ${message.text}`;

  if (message.metadata?.category) {
    content += ` [Category: ${message.metadata.category}]`;
  }

  if (message.metadata?.sentiment?.type) {
    content += ` [Sentiment: ${message.metadata.sentiment.type}]`;
  }

  return content;
}
```

### 3.3 Batch Storage for Conversation History

```javascript
/// batchStoreConversation.js
///
/// Cloud Function to batch store entire conversation history.
/// Useful for initial migration or periodic backups.
///
/// Created: 2025-10-20

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

const SUPERMEMORY_API_KEY = functions.config().supermemory.api_key;
const SUPERMEMORY_BASE_URL = 'https://api.supermemory.ai/v3';

const supermemoryClient = axios.create({
  baseURL: SUPERMEMORY_BASE_URL,
  headers: {
    'Authorization': `Bearer ${SUPERMEMORY_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

/**
 * Callable function to batch store conversation history
 */
exports.batchStoreConversation = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { conversationID } = data;

  if (!conversationID) {
    throw new functions.https.HttpsError('invalid-argument', 'conversationID is required');
  }

  try {
    // Fetch all messages in conversation
    const messagesSnapshot = await admin.firestore()
      .collection('conversations')
      .doc(conversationID)
      .collection('messages')
      .orderBy('createdAt', 'asc')
      .get();

    const messages = messagesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    console.log(`📦 Batch storing ${messages.length} messages for conversation ${conversationID}`);

    // Store each message
    const results = await Promise.allSettled(
      messages.map(async (message) => {
        const supermemoryDoc = {
          customId: message.id,
          content: `${message.senderID}: ${message.text}`,
          metadata: {
            conversationID: conversationID,
            senderID: message.senderID,
            timestamp: message.createdAt.toDate().toISOString()
          },
          containerTags: [message.senderID, conversationID, 'sorted']
        };

        return await supermemoryClient.post('/documents', supermemoryDoc);
      })
    );

    const successCount = results.filter(r => r.status === 'fulfilled').length;
    const failCount = results.filter(r => r.status === 'rejected').length;

    console.log(`✅ Batch store complete: ${successCount} success, ${failCount} failed`);

    return {
      success: true,
      totalMessages: messages.length,
      successCount,
      failCount
    };

  } catch (error) {
    console.error('❌ Batch store failed:', error.message);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## 4. RAG Queries for Context Retrieval

### 4.1 Query Strategy

**When to Query:**
- User taps "Draft Reply" button
- AI needs context for smart response generation
- User requests conversation summary

**What to Query:**
```javascript
{
  "query": "What did we discuss about the brand partnership?",
  "containerTags": ["conv-123", "user-creator-id"], // Scope to specific conversation/user
  "limit": 5 // Top 5 most relevant memories
}
```

### 4.2 Cloud Function: Query Supermemory for Context

```javascript
/// querySupermemoryContext.js
///
/// Cloud Function to query Supermemory for conversation context.
/// Used when generating AI-powered smart replies.
///
/// Created: 2025-10-20

const functions = require('firebase-functions');
const axios = require('axios');

const SUPERMEMORY_API_KEY = functions.config().supermemory.api_key;
const SUPERMEMORY_BASE_URL = 'https://api.supermemory.ai/v3';
const OPENAI_API_KEY = functions.config().openai.api_key;

const supermemoryClient = axios.create({
  baseURL: SUPERMEMORY_BASE_URL,
  headers: {
    'Authorization': `Bearer ${SUPERMEMORY_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

/**
 * Query Supermemory for relevant conversation context
 */
async function querySupermemoryContext(conversationID, query, limit = 5) {
  try {
    const response = await supermemoryClient.post('/search', {
      query: query,
      containerTags: [conversationID, 'sorted'],
      limit: limit
    });

    // Extract relevant memories
    const memories = response.data.results.map(result => ({
      content: result.content,
      relevanceScore: result.score,
      timestamp: result.metadata?.timestamp,
      senderID: result.metadata?.senderID
    }));

    console.log(`✅ Retrieved ${memories.length} relevant memories from Supermemory`);

    return memories;

  } catch (error) {
    console.error('❌ Supermemory query failed:', error.message);
    return []; // Return empty array on failure
  }
}

/**
 * Callable function: Generate smart reply with Supermemory context
 */
exports.generateSmartReply = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { conversationID, incomingMessage, creatorID } = data;

  if (!conversationID || !incomingMessage) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'conversationID and incomingMessage are required'
    );
  }

  try {
    // 1. Query Supermemory for relevant context
    const contextQuery = `Conversation about: ${incomingMessage}`;
    const relevantMemories = await querySupermemoryContext(conversationID, contextQuery, 5);

    // 2. Fetch creator's writing style (from Firestore)
    const creatorDoc = await admin.firestore()
      .collection('users')
      .doc(creatorID)
      .get();

    const creatorStyle = creatorDoc.data()?.writingStyle || 'friendly and professional';

    // 3. Build context-aware prompt
    const contextSummary = relevantMemories.length > 0
      ? relevantMemories.map(m => m.content).join('\n')
      : 'No previous conversation context available.';

    const prompt = `
You are drafting a reply for a content creator to this message:

"${incomingMessage}"

CONVERSATION CONTEXT (from past interactions):
${contextSummary}

CREATOR'S WRITING STYLE: ${creatorStyle}

Generate a personalized reply that:
1. References relevant past conversation context if applicable
2. Matches the creator's authentic voice and tone
3. Is concise and natural (2-3 sentences max)
4. Sounds human, not like AI

Reply:`;

    // 4. Call OpenAI with context
    const openaiResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4',
        messages: [
          { role: 'system', content: 'You are a helpful assistant that drafts authentic social media replies.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 150
      },
      {
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const draftReply = openaiResponse.data.choices[0].message.content.trim();

    console.log(`✅ Generated smart reply with ${relevantMemories.length} context memories`);

    return {
      success: true,
      draftReply,
      contextUsed: relevantMemories.length,
      relevantContext: relevantMemories.slice(0, 3) // Return top 3 for debugging
    };

  } catch (error) {
    console.error('❌ Smart reply generation failed:', error.message);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

### 4.3 iOS Implementation: Call Smart Reply Function

```swift
/// AIService.swift
///
/// Service layer for AI features, including smart reply generation.
/// Calls Firebase Cloud Functions which query Supermemory.
///
/// Created: 2025-10-20

import Foundation
import FirebaseFunctions

actor AIService {
    // MARK: - Dependencies

    private let functions: Functions

    // MARK: - Initialization

    init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    // MARK: - Smart Reply

    /// Generate smart reply using Supermemory context
    func generateSmartReply(
        conversationID: String,
        incomingMessage: String,
        creatorID: String
    ) async throws -> SmartReplyResponse {

        // Call Cloud Function
        let callable = functions.httpsCallable("generateSmartReply")

        let requestData: [String: Any] = [
            "conversationID": conversationID,
            "incomingMessage": incomingMessage,
            "creatorID": creatorID
        ]

        do {
            let result = try await callable.call(requestData)

            guard let data = result.data as? [String: Any],
                  let draftReply = data["draftReply"] as? String,
                  let contextUsed = data["contextUsed"] as? Int else {
                throw AIServiceError.invalidResponse
            }

            print("✅ Smart reply generated with \(contextUsed) context memories")

            return SmartReplyResponse(
                draftReply: draftReply,
                contextUsed: contextUsed
            )

        } catch {
            print("❌ Smart reply failed: \(error)")
            throw AIServiceError.generationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Response Model

struct SmartReplyResponse: Sendable {
    let draftReply: String
    let contextUsed: Int
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidResponse
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .generationFailed(let details):
            return "AI generation failed: \(details)"
        }
    }
}
```

### 4.4 Advanced RAG Query: Conversation Summary

```javascript
/// summarizeConversation.js
///
/// Cloud Function to generate conversation summary using Supermemory.
///
/// Created: 2025-10-20

exports.summarizeConversation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { conversationID } = data;

  try {
    // Query ALL memories for this conversation
    const response = await supermemoryClient.post('/search', {
      query: 'Summarize the entire conversation',
      containerTags: [conversationID, 'sorted'],
      limit: 50 // Get more context for summary
    });

    const memories = response.data.results.map(r => r.content).join('\n');

    // Generate summary with OpenAI
    const summaryPrompt = `
Summarize this conversation in 3-5 bullet points:

${memories}

Summary:`;

    const openaiResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4',
        messages: [
          { role: 'system', content: 'You are a helpful assistant that summarizes conversations.' },
          { role: 'user', content: summaryPrompt }
        ],
        temperature: 0.5,
        max_tokens: 300
      },
      {
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const summary = openaiResponse.data.choices[0].message.content.trim();

    return {
      success: true,
      summary,
      messagesAnalyzed: response.data.results.length
    };

  } catch (error) {
    console.error('❌ Summary generation failed:', error.message);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## 5. Error Handling & Retry Strategies

### 5.1 Error Types

```javascript
// SupermemoryError.js - Error handling utilities

class SupermemoryError extends Error {
  constructor(message, type, statusCode) {
    super(message);
    this.type = type;
    this.statusCode = statusCode;
  }
}

// Error types
const ErrorTypes = {
  AUTHENTICATION: 'authentication_error',
  RATE_LIMIT: 'rate_limit_error',
  NETWORK: 'network_error',
  INVALID_REQUEST: 'invalid_request',
  SERVER_ERROR: 'server_error'
};

// Parse error from response
function parseSupermemoryError(error) {
  if (error.response) {
    const { status, data } = error.response;

    switch (status) {
      case 401:
        return new SupermemoryError(
          'Invalid API key',
          ErrorTypes.AUTHENTICATION,
          401
        );

      case 429:
        return new SupermemoryError(
          'Rate limit exceeded',
          ErrorTypes.RATE_LIMIT,
          429
        );

      case 400:
        return new SupermemoryError(
          data.error?.message || 'Invalid request',
          ErrorTypes.INVALID_REQUEST,
          400
        );

      case 500:
      case 502:
      case 503:
        return new SupermemoryError(
          'Supermemory server error',
          ErrorTypes.SERVER_ERROR,
          status
        );

      default:
        return new SupermemoryError(
          'Unknown error',
          'unknown_error',
          status
        );
    }
  } else if (error.request) {
    return new SupermemoryError(
      'Network error - no response received',
      ErrorTypes.NETWORK,
      0
    );
  } else {
    return new SupermemoryError(
      error.message,
      'unknown_error',
      0
    );
  }
}

module.exports = { SupermemoryError, ErrorTypes, parseSupermemoryError };
```

### 5.2 Retry Strategy with Exponential Backoff

```javascript
/// retryWithBackoff.js
///
/// Utility function for retrying failed Supermemory requests.
///
/// Created: 2025-10-20

const { parseSupermemoryError, ErrorTypes } = require('./SupermemoryError');

/**
 * Retry function with exponential backoff
 *
 * @param {Function} fn - Async function to retry
 * @param {number} maxRetries - Maximum retry attempts (default: 3)
 * @param {number} initialDelay - Initial delay in ms (default: 1000)
 * @returns {Promise} Result of function or throws error
 */
async function retryWithBackoff(fn, maxRetries = 3, initialDelay = 1000) {
  let lastError;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      // Attempt operation
      return await fn();

    } catch (error) {
      const parsedError = parseSupermemoryError(error);
      lastError = parsedError;

      // Don't retry authentication or invalid request errors
      if (
        parsedError.type === ErrorTypes.AUTHENTICATION ||
        parsedError.type === ErrorTypes.INVALID_REQUEST
      ) {
        throw parsedError;
      }

      // If last attempt, throw error
      if (attempt === maxRetries) {
        console.error(`❌ All ${maxRetries} retry attempts failed`);
        throw parsedError;
      }

      // Calculate delay with exponential backoff + jitter
      const delay = initialDelay * Math.pow(2, attempt) + Math.random() * 1000;

      console.warn(
        `⚠️ Attempt ${attempt + 1} failed: ${parsedError.message}. ` +
        `Retrying in ${Math.round(delay)}ms...`
      );

      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

module.exports = { retryWithBackoff };
```

### 5.3 Using Retry Strategy

```javascript
/// supermemoryService.js
///
/// Service with built-in retry logic for Supermemory operations.
///
/// Created: 2025-10-20

const { retryWithBackoff } = require('./retryWithBackoff');
const { supermemoryClient } = require('./config');

class SupermemoryService {
  /**
   * Add document with retry
   */
  static async addDocument(document) {
    return await retryWithBackoff(async () => {
      const response = await supermemoryClient.post('/documents', document);
      return response.data;
    });
  }

  /**
   * Search with retry
   */
  static async search(query, containerTags, limit = 5) {
    return await retryWithBackoff(async () => {
      const response = await supermemoryClient.post('/search', {
        query,
        containerTags,
        limit
      });
      return response.data.results;
    });
  }

  /**
   * Delete document with retry
   */
  static async deleteDocument(documentID) {
    return await retryWithBackoff(async () => {
      const response = await supermemoryClient.delete(`/documents/${documentID}`);
      return response.data;
    });
  }
}

module.exports = { SupermemoryService };
```

### 5.4 Fallback Strategy

When Supermemory fails, gracefully degrade AI features:

```javascript
/// generateSmartReplyWithFallback.js
///
/// Smart reply generation with Supermemory fallback.
///
/// Created: 2025-10-20

async function generateSmartReplyWithFallback(conversationID, incomingMessage, creatorID) {
  let contextMemories = [];
  let contextSource = 'none';

  try {
    // Try Supermemory first
    contextMemories = await SupermemoryService.search(
      `Context for: ${incomingMessage}`,
      [conversationID, 'sorted'],
      5
    );
    contextSource = 'supermemory';
    console.log(`✅ Using Supermemory context: ${contextMemories.length} memories`);

  } catch (error) {
    console.warn('⚠️ Supermemory unavailable, falling back to Firestore context');

    try {
      // Fallback: Fetch recent messages from Firestore
      const recentMessages = await admin.firestore()
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();

      contextMemories = recentMessages.docs.map(doc => ({
        content: `${doc.data().senderID}: ${doc.data().text}`,
        relevanceScore: 1.0
      }));

      contextSource = 'firestore';
      console.log(`✅ Using Firestore context: ${contextMemories.length} messages`);

    } catch (firestoreError) {
      console.error('❌ Both Supermemory and Firestore failed, generating reply without context');
      contextSource = 'none';
    }
  }

  // Generate reply with available context
  const contextSummary = contextMemories.length > 0
    ? contextMemories.map(m => m.content).join('\n')
    : 'No previous conversation context available.';

  const prompt = buildPrompt(incomingMessage, contextSummary, creatorID);
  const draftReply = await callOpenAI(prompt);

  return {
    draftReply,
    contextSource,
    contextUsed: contextMemories.length
  };
}
```

---

## 6. Implementation Examples

### 6.1 Complete Cloud Function Example

```javascript
/// index.js - Complete Cloud Functions setup
///
/// All Supermemory integration functions in one file.
///
/// Created: 2025-10-20

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Supermemory configuration
const SUPERMEMORY_API_KEY = functions.config().supermemory.api_key;
const SUPERMEMORY_BASE_URL = 'https://api.supermemory.ai/v3';
const OPENAI_API_KEY = functions.config().openai.api_key;

const supermemoryClient = axios.create({
  baseURL: SUPERMEMORY_BASE_URL,
  headers: {
    'Authorization': `Bearer ${SUPERMEMORY_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

// Import utilities
const { retryWithBackoff } = require('./utils/retryWithBackoff');

// ========================================
// 1. Store Message in Supermemory
// ========================================

exports.storeMessageToSupermemory = functions.firestore
  .document('conversations/{conversationID}/messages/{messageID}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const { conversationID, messageID } = context.params;

    try {
      const supermemoryDoc = {
        customId: messageID,
        content: `${message.senderID}: ${message.text}`,
        metadata: {
          conversationID,
          senderID: message.senderID,
          timestamp: message.createdAt.toDate().toISOString()
        },
        containerTags: [message.senderID, conversationID, 'sorted']
      };

      const response = await retryWithBackoff(async () => {
        return await supermemoryClient.post('/documents', supermemoryDoc);
      });

      await snapshot.ref.update({ supermemoryID: response.data.id });

      console.log(`✅ Message ${messageID} stored in Supermemory`);
      return { success: true };

    } catch (error) {
      console.error(`❌ Failed to store message:`, error.message);
      return { success: false, error: error.message };
    }
  });

// ========================================
// 2. Generate Smart Reply
// ========================================

exports.generateSmartReply = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { conversationID, incomingMessage, creatorID } = data;

  try {
    // Query Supermemory for context
    const searchResults = await retryWithBackoff(async () => {
      return await supermemoryClient.post('/search', {
        query: `Context for: ${incomingMessage}`,
        containerTags: [conversationID, 'sorted'],
        limit: 5
      });
    });

    const contextMemories = searchResults.data.results || [];
    const contextSummary = contextMemories.map(r => r.content).join('\n');

    // Build prompt
    const prompt = `
Draft a reply to: "${incomingMessage}"

Past conversation context:
${contextSummary || 'No previous context available.'}

Generate a personalized, authentic reply (2-3 sentences max):`;

    // Call OpenAI
    const openaiResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4',
        messages: [
          { role: 'system', content: 'You draft authentic social media replies.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 150
      },
      {
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const draftReply = openaiResponse.data.choices[0].message.content.trim();

    return {
      success: true,
      draftReply,
      contextUsed: contextMemories.length
    };

  } catch (error) {
    console.error('❌ Smart reply failed:', error.message);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ========================================
// 3. Batch Store Conversation
// ========================================

exports.batchStoreConversation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { conversationID } = data;

  const messagesSnapshot = await admin.firestore()
    .collection('conversations')
    .doc(conversationID)
    .collection('messages')
    .orderBy('createdAt', 'asc')
    .get();

  const messages = messagesSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  const results = await Promise.allSettled(
    messages.map(async (message) => {
      return await retryWithBackoff(async () => {
        return await supermemoryClient.post('/documents', {
          customId: message.id,
          content: `${message.senderID}: ${message.text}`,
          metadata: { conversationID },
          containerTags: [conversationID, 'sorted']
        });
      });
    })
  );

  const successCount = results.filter(r => r.status === 'fulfilled').length;

  return {
    success: true,
    totalMessages: messages.length,
    successCount
  };
});
```

### 6.2 iOS Integration Example

```swift
/// SmartReplyViewModel.swift
///
/// ViewModel for smart reply feature using Supermemory-powered AI.
///
/// Created: 2025-10-20

import Foundation
import SwiftUI

@MainActor
final class SmartReplyViewModel: ObservableObject {
    // MARK: - Dependencies

    private let aiService: AIService

    // MARK: - Published State

    @Published var draftReply: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var contextUsed: Int = 0

    // MARK: - Initialization

    init(aiService: AIService = AIService()) {
        self.aiService = aiService
    }

    // MARK: - Actions

    /// Generate smart reply for incoming message
    func generateReply(
        conversationID: String,
        incomingMessage: String,
        creatorID: String
    ) async {
        isGenerating = true
        errorMessage = nil

        do {
            let response = try await aiService.generateSmartReply(
                conversationID: conversationID,
                incomingMessage: incomingMessage,
                creatorID: creatorID
            )

            draftReply = response.draftReply
            contextUsed = response.contextUsed

            print("✅ Smart reply generated with \(contextUsed) context memories")

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Smart reply generation failed: \(error)")
        }

        isGenerating = false
    }

    /// Clear draft
    func clearDraft() {
        draftReply = ""
        contextUsed = 0
        errorMessage = nil
    }
}
```

---

## 7. Privacy & Data Management

### 7.1 Privacy Controls

Allow users to control Supermemory storage:

```javascript
/// privacySettings.js
///
/// User privacy controls for Supermemory storage.
///
/// Created: 2025-10-20

exports.updateSupermemoryPrivacy = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { allowSupermemoryStorage } = data;
  const userID = context.auth.uid;

  // Update user preferences
  await admin.firestore()
    .collection('users')
    .doc(userID)
    .update({
      'aiPreferences.allowSupermemoryStorage': allowSupermemoryStorage
    });

  // If disabled, optionally delete user's Supermemory data
  if (!allowSupermemoryStorage) {
    console.log(`🗑️ User ${userID} opted out of Supermemory storage`);
    // Note: Supermemory doesn't provide bulk delete by tag yet
    // Would need to track and delete individual documents
  }

  return { success: true };
});

/// Check privacy settings before storing
async function shouldStoreInSupermemory(userID) {
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userID)
    .get();

  return userDoc.data()?.aiPreferences?.allowSupermemoryStorage !== false;
}
```

### 7.2 Data Deletion

```javascript
/// deleteSupermemoryData.js
///
/// Delete user's data from Supermemory on account deletion.
///
/// Created: 2025-10-20

exports.deleteUserSupermemoryData = functions.auth.user().onDelete(async (user) => {
  const userID = user.uid;

  try {
    // Fetch all user's messages with Supermemory IDs
    const messagesSnapshot = await admin.firestore()
      .collectionGroup('messages')
      .where('senderID', '==', userID)
      .where('supermemoryID', '!=', null)
      .get();

    // Delete each from Supermemory
    const deletions = messagesSnapshot.docs.map(async (doc) => {
      const supermemoryID = doc.data().supermemoryID;

      try {
        await supermemoryClient.delete(`/documents/${supermemoryID}`);
        console.log(`✅ Deleted Supermemory document: ${supermemoryID}`);
      } catch (error) {
        console.error(`❌ Failed to delete ${supermemoryID}:`, error.message);
      }
    });

    await Promise.allSettled(deletions);

    console.log(`✅ Deleted ${messagesSnapshot.size} Supermemory documents for user ${userID}`);

  } catch (error) {
    console.error('❌ Supermemory data deletion failed:', error.message);
  }
});
```

---

## Summary

This guide provides complete Supermemory integration for Sorted:

✅ **Authentication**: Bearer token auth, Cloud Functions configuration
✅ **Storing Conversations**: Automatic storage on message creation, batch storage
✅ **RAG Queries**: Context retrieval for smart replies, conversation summaries
✅ **Error Handling**: Retry with exponential backoff, fallback strategies
✅ **Implementation Examples**: Complete Cloud Functions and iOS integration
✅ **Privacy & Data Management**: User privacy controls, data deletion

**Key Benefits:**
- **Unlimited Context**: No more token window limitations
- **Personalized AI**: Responses match creator's authentic voice
- **Context Recall**: References relevant past conversations
- **Scalable**: Handles growing conversation history efficiently

**Next Steps:**
1. Deploy Cloud Functions with Supermemory integration
2. Test smart reply generation with real conversations
3. Monitor Supermemory API usage and costs
4. Gather user feedback on response quality

---

**END OF SUPERMEMORY INTEGRATION GUIDE**
