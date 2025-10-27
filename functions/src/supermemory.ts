/**
 * Supermemory RAG Integration for Buzzbox
 *
 * Provides secure server-side access to Supermemory API for:
 * - Storing Q&A pairs from creator replies
 * - Searching memories for AI context enhancement
 *
 * API Key: Stored securely in Firebase as SUPERMEMORY_API_KEY secret
 * Authorization: Creator-only access enforced server-side
 *
 * [Source: Story 9.0 - Supermemory Cloud Functions]
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Supermemory API configuration
const SUPERMEMORY_BASE_URL = "https://api.supermemory.ai";
const CREATOR_EMAIL = "andrewsheim@gmail.com";

// Interfaces for type safety
interface AddMemoryRequest {
  content: string;
  metadata?: Record<string, string>;
}

interface AddMemoryResponse {
  success: boolean;
  memoryId?: string;
  timestamp: string;
}

interface SearchMemoriesRequest {
  query: string;
  limit?: number;
}

interface SearchMemoriesResponse {
  memories: Array<{
    id: string;
    content: string;
    metadata?: Record<string, string>;
    score?: number;
  }>;
  searchedAt: string;
}

/**
 * Adds a memory to Supermemory API.
 * Only accessible by authenticated creator.
 * API key stored securely as Firebase secret.
 */
export const addSupermemoryMemory = onCall<AddMemoryRequest, Promise<AddMemoryResponse>>({
  region: "us-central1",
  secrets: ["SUPERMEMORY_API_KEY"],
  timeoutSeconds: 30,
}, async (request) => {
  logger.info("addSupermemoryMemory invoked", {
    uid: request.auth?.uid,
    hasContent: !!request.data.content,
  });

  // Check authentication
  if (!request.auth) {
    logger.warn("Unauthenticated request");
    throw new HttpsError("unauthenticated", "Must be signed in to store memories");
  }

  // Check creator authorization
  const userEmail = request.auth.token.email;
  if (userEmail !== CREATOR_EMAIL) {
    logger.warn("Unauthorized user attempted to store memory", {
      uid: request.auth.uid,
      email: userEmail,
    });
    throw new HttpsError("permission-denied", "Only creator can store memories");
  }

  const {content, metadata} = request.data;

  // Validate input
  if (!content || content.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Content cannot be empty");
  }

  try {
    // Call Supermemory API (server-side, API key secure)
    const apiKey = process.env.SUPERMEMORY_API_KEY;
    if (!apiKey) {
      logger.error("SUPERMEMORY_API_KEY not configured");
      throw new HttpsError("internal", "Service configuration error");
    }

    logger.info("Calling Supermemory API", {
      contentLength: content.length,
      hasMetadata: !!metadata,
    });

    const response = await fetch(`${SUPERMEMORY_BASE_URL}/v3/documents`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        content,
        containerTag: "andrew-heim-response",
        metadata: metadata || {},
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Supermemory API error", {
        status: response.status,
        statusText: response.statusText,
        body: errorText,
      });
      throw new HttpsError("internal", `Supermemory API error: ${response.status}`);
    }

    const result = await response.json();

    logger.info("Memory stored successfully", {
      memoryId: result.id,
      uid: request.auth.uid,
    });

    return {
      success: true,
      memoryId: result.id,
      timestamp: new Date().toISOString(),
    };
  } catch (error: unknown) {
    // Don't expose internal errors to client
    if (error instanceof HttpsError) {
      throw error;
    }

    const err = error as Error;
    logger.error("Failed to store memory", {
      error: err.message,
      stack: err.stack,
      uid: request.auth.uid,
    });

    throw new HttpsError("internal", "Failed to store memory");
  }
});

/**
 * Searches memories in Supermemory API.
 * Accessible by all authenticated users.
 * Returns empty array on errors for graceful degradation.
 */
export const searchSupermemoryMemories = onCall<SearchMemoriesRequest, Promise<SearchMemoriesResponse>>({
  region: "us-central1",
  secrets: ["SUPERMEMORY_API_KEY"],
  timeoutSeconds: 10, // 10 second timeout for search
}, async (request) => {
  logger.info("searchSupermemoryMemories invoked", {
    uid: request.auth?.uid,
    query: request.data.query?.substring(0, 50), // Log first 50 chars
  });

  // Check authentication
  if (!request.auth) {
    logger.warn("Unauthenticated search request");
    throw new HttpsError("unauthenticated", "Must be signed in to search memories");
  }

  const {query, limit = 3} = request.data;

  // Validate input
  if (!query || query.trim().length === 0) {
    logger.warn("Empty query provided");
    return {
      memories: [],
      searchedAt: new Date().toISOString(),
    };
  }

  try {
    const apiKey = process.env.SUPERMEMORY_API_KEY;
    if (!apiKey) {
      logger.error("SUPERMEMORY_API_KEY not configured");
      // Graceful degradation: return empty results
      return {
        memories: [],
        searchedAt: new Date().toISOString(),
      };
    }

    logger.info("Searching Supermemory", {
      queryLength: query.length,
      limit,
    });

    const response = await fetch(`${SUPERMEMORY_BASE_URL}/v4/search`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        q: query,
        limit: limit || 3,
        containerTag: "andrew-heim-response",
        threshold: 0.5,
        rerank: true,
      }),
    });

    if (!response.ok) {
      logger.warn("Supermemory search API error", {
        status: response.status,
        statusText: response.statusText,
      });
      // Graceful degradation: return empty results
      return {
        memories: [],
        searchedAt: new Date().toISOString(),
      };
    }

    const result = await response.json();
    const memories = result.results || [];

    logger.info("Search completed successfully", {
      resultCount: memories.length,
      uid: request.auth.uid,
    });

    return {
      memories: memories.map((m: Record<string, unknown>) => ({
        id: (m.id || String(Math.random())) as string,
        content: (m.memory || "") as string,
        metadata: m.metadata as Record<string, string> | undefined,
        score: (m.similarity) as number | undefined,
      })),
      searchedAt: new Date().toISOString(),
    };
  } catch (error: unknown) {
    // Graceful degradation: don't throw, return empty
    const err = error as Error;
    logger.error("Search failed", {
      error: err.message,
      stack: err.stack,
      uid: request.auth.uid,
    });

    return {
      memories: [],
      searchedAt: new Date().toISOString(),
    };
  }
});
