# Epic 7: X (Twitter) Integration for Multi-Platform Inbox

**Phase:** Post-MVP Enhancement
**Priority:** P1 (High Value - Multi-Platform Creator Tool)
**Estimated Time:** 12-14 hours
**Epic Owner:** Product Owner
**Dependencies:** Epic 5 (Single-Creator Platform), Epic 6 (AI-Powered Inbox)

---

## 📋 Strategic Context

### Why This Epic Exists

**Vision:** Transform BuzzBox from a single-platform messaging app into a **unified multi-platform creator inbox** inspired by Superhuman.

**Current State:** After Epic 6, Andrew has an AI-powered inbox for BuzzBox DMs with smart replies, auto-categorization, and FAQ responses.

**Problem:** Andrew manages X (Twitter) mentions separately in the X app, splitting his attention across multiple platforms.

**Solution:** Integrate X authentication and API to display X mentions/replies alongside BuzzBox messages in one unified inbox with account switcher.

**Inspiration:** Superhuman's approach - "Sign in with Google" immediately connects your Gmail and you're ready to go. We'll do the same with "Sign in with X" or "Connect X Account" from settings.

---

## 🎯 What This Epic Delivers

### User Experience

**For Andrew (The Creator):**
- ✅ **Sign in with X** - OAuth login option (Superhuman-style, X account auto-connected)
- ✅ **Connect X Account** - Link X to existing BuzzBox account (from Settings)
- ✅ **Multi-Account Support** - Connect multiple X accounts, switch between them
- ✅ **Unified Inbox Tabs** - [ BuzzBox | @andrewsheim | @other_account ]
- ✅ **X Mentions Feed** - See all replies to his tweets and mentions in one place
- ✅ **Reply from App** - Compose and send X replies without leaving BuzzBox
- ✅ **Conversation Threading** - See full X conversation context
- ✅ **AI Smart Replies** - Use existing AI for X replies (reuse Epic 6 features!)

**For Fans:**
- ✅ Same features available (optional X connection)
- ✅ Manage their own X engagement from BuzzBox

**What's New:**
- 🆕 "Sign in with X" button on login screen
- 🆕 "Connect X Account" in Settings → Connected Accounts
- 🆕 Account switcher tabs in InboxView
- 🆕 X mentions/replies display (similar to MessageBubbleView)
- 🆕 Reply composer for X with character counter (280 chars)
- 🆕 OAuth flow with secure token storage (Keychain)
- 🆕 Multiple X accounts per user

---

## 🏗️ Architecture Overview

### Authentication & API Integration

```
iOS App → X OAuth 2.0 → X API → Firebase (token storage) → Keychain (tokens)
         ↓
      Firebase Auth (Custom Token) + X Account Linking
```

**Why OAuth 2.0 + Firebase Custom Tokens:**
- ✅ Users authenticate WITH X (like Superhuman)
- ✅ X account tokens stored securely in iOS Keychain
- ✅ Firebase account links to X for multi-provider auth
- ✅ Can have both email + X auth methods on same account
- ✅ Cloud Functions can generate Firebase custom tokens from X OAuth

**X API Access:**
- **Read Permissions:** Fetch mentions (`GET /2/users/:id/mentions`)
- **Write Permissions:** Post replies (`POST /2/tweets`)
- **Rate Limits:** Basic tier ($100/month) = 10,000 tweets/month
- **Authentication:** OAuth 2.0 bearer tokens (refresh every 2 hours)

**Pricing Consideration:**
- **Free Tier:** 50-100 requests/month (unusable)
- **Basic Tier ($100/month):** 10,000 tweets/month (recommended minimum)
- **Pro Tier ($5,000/month):** 1M tweets/month (if scaling)

---

## 📊 High-Level Implementation Overview

### 1. X Developer Setup (Prerequisites)

**Before Development:**
1. Register for X Developer account (developer.x.com)
2. Create app in X Developer Portal
3. Get API keys: `client_id`, `client_secret`
4. Configure OAuth 2.0 redirect URLs: `buzzbox://oauth-callback`
5. Request permissions: `tweet.read`, `users.read`, `tweet.write`, `offline.access`
6. Subscribe to API tier (Basic $100/month minimum)

**Environment Variables:**
```bash
# Store in Cloud Functions secrets
X_API_CLIENT_ID=your_client_id
X_API_CLIENT_SECRET=your_client_secret
```

### 2. Authentication Flows (Two Options)

**Option A: Sign in with X (Superhuman-style)**
```
User taps "Sign in with X"
  → OAuth 2.0 web flow (ASWebAuthenticationSession)
  → User logs into X, authorizes app
  → App receives auth code
  → Exchange for access_token + refresh_token
  → Call Cloud Function to generate Firebase custom token
  → Sign into Firebase with custom token
  → ✅ User logged into BuzzBox AND X connected
  → Store X tokens in Keychain
```

**Option B: Connect X to Existing Account**
```
User logged in with email
  → Settings → "Connect X Account"
  → OAuth 2.0 web flow
  → Exchange for tokens
  → Link X credential to Firebase Auth user
  → Store X tokens in Keychain
  → Update Firestore user doc with X account info
  → ✅ Email + X both linked to same Firebase UID
```

### 3. iOS Components

**New Services:**
- `XOAuthService.swift` - OAuth 2.0 flow (ASWebAuthenticationSession)
- `XAPIService.swift` - X API calls (mentions, post replies)
- `XAccountManager.swift` - Multi-account management, token refresh

**New Models:**
- `XAccount` - X account metadata (username, userId, tokens)
- `XMention` - Mention/reply from X (similar to MessageEntity)
- `XConversation` - Threaded conversation context

**UI Updates:**
- `LoginView` - Add "Sign in with X" button
- `ProfileView` / `SettingsView` - Add "Connected Accounts" section
- `InboxView` - Add account switcher tabs (Picker or SegmentedControl)
- `XMentionsView` - Display X mentions (similar to InboxView)
- `XReplyComposerView` - Reply to X mentions (character counter)

### 4. Firebase Integration

**Cloud Function: Generate Custom Token**
```typescript
// functions/src/x-auth.ts
export const generateCustomTokenFromX = onCall(async (request) => {
  // Verify X OAuth token
  // Create/get Firebase user
  // Generate custom token
  // Return to iOS
});
```

**Firestore Structure:**
```
users/{userId}/
  authProviders: ["password", "twitter.com"]  // Multi-provider
  xAccounts: {
    account1: {
      xUserId: "123456789"
      username: "andrewsheim"
      displayName: "Andrew Heim Dev"
      linkedAt: Timestamp
    }
    account2: { ... }
  }
```

**Token Storage:**
- **Keychain (iOS):** OAuth tokens (access_token, refresh_token)
- **Firestore:** X account metadata only (no tokens!)
- **Security:** Tokens never leave the device

### 5. X API Integration

**Fetch Mentions:**
```swift
// XAPIService.swift
func fetchMentions(for account: XAccount) async throws -> [XMention] {
    let url = "https://api.x.com/2/users/\(account.xUserId)/mentions"
    // Add expansions: conversation_id, referenced_tweets
    // Parse and return XMention objects
}
```

**Post Reply:**
```swift
func postReply(text: String, inReplyTo tweetId: String, account: XAccount) async throws {
    let url = "https://api.x.com/2/tweets"
    // POST with OAuth 2.0 bearer token
    // Body: { "text": text, "reply": { "in_reply_to_tweet_id": tweetId } }
}
```

**Token Refresh (Automatic):**
```swift
func refreshTokenIfNeeded(for account: XAccount) async throws {
    // Check token expiry (tokens last 2 hours)
    // Use refresh_token to get new access_token
    // Update Keychain
}
```

---

## 📝 User Stories

### Story 7.0: X Developer Account & API Setup (1 hour)

**As a developer, I want to set up X Developer account and API credentials so the app can authenticate and fetch X data.**

**Acceptance Criteria:**
- [ ] X Developer account created at developer.x.com
- [ ] App registered in X Developer Portal
- [ ] OAuth 2.0 credentials obtained (client_id, client_secret)
- [ ] Redirect URL configured: `buzzbox://oauth-callback`
- [ ] API permissions requested: `tweet.read`, `users.read`, `tweet.write`, `offline.access`
- [ ] API tier subscribed (Basic $100/month minimum)
- [ ] Credentials stored in Cloud Functions secrets:
```bash
firebase functions:secrets:set X_API_CLIENT_ID
firebase functions:secrets:set X_API_CLIENT_SECRET
```

**Testing:**
- [ ] Can access X Developer Portal
- [ ] Credentials work in Postman test (OAuth flow)
- [ ] Secrets accessible in Cloud Functions

**Estimate:** 1 hour

---

### Story 7.1: X OAuth Service Layer (2 hours)

**As a developer, I want an OAuth service to handle X authentication flow so users can securely connect their X accounts.**

**Create: `buzzbox/Core/Services/XOAuthService.swift`**

```swift
import AuthenticationServices
import Foundation

/// Handles X (Twitter) OAuth 2.0 authentication flow
@MainActor
final class XOAuthService: NSObject, ObservableObject {

    // MARK: - Configuration

    private let clientId = "YOUR_X_API_CLIENT_ID"
    private let redirectURI = "buzzbox://oauth-callback"
    private let scopes = ["tweet.read", "users.read", "tweet.write", "offline.access"]

    // MARK: - OAuth 2.0 Flow

    struct OAuthResult {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let tokenType: String
    }

    /// Initiate OAuth 2.0 flow with PKCE
    func authenticate() async throws -> OAuthResult {
        // 1. Generate PKCE challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString

        // 2. Build authorize URL
        var components = URLComponents(string: "https://x.com/i/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        // 3. Present OAuth web view
        let authCode = try await presentAuthSession(url: components.url!, redirectURI: redirectURI)

        // 4. Exchange auth code for tokens
        return try await exchangeCodeForTokens(code: authCode, codeVerifier: codeVerifier)
    }

    /// Present ASWebAuthenticationSession for OAuth
    private func presentAuthSession(url: URL, redirectURI: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "buzzbox"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: OAuthError.invalidCallback)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.start()
        }
    }

    /// Exchange authorization code for access/refresh tokens
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> OAuthResult {
        let url = URL(string: "https://api.x.com/2/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
            "client_id": clientId
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }

        let json = try JSONDecoder().decode(TokenResponse.self, from: data)

        return OAuthResult(
            accessToken: json.access_token,
            refreshToken: json.refresh_token,
            expiresIn: json.expires_in,
            tokenType: json.token_type
        )
    }

    /// Refresh expired access token
    func refreshAccessToken(refreshToken: String) async throws -> OAuthResult {
        let url = URL(string: "https://api.x.com/2/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenRefreshFailed
        }

        let json = try JSONDecoder().decode(TokenResponse.self, from: data)

        return OAuthResult(
            accessToken: json.access_token,
            refreshToken: json.refresh_token,
            expiresIn: json.expires_in,
            tokenType: json.token_type
        )
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension XOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Supporting Types

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
}

enum OAuthError: LocalizedError {
    case invalidCallback
    case tokenExchangeFailed
    case tokenRefreshFailed

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "OAuth callback was invalid"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        }
    }
}
```

**Acceptance Criteria:**
- [ ] OAuth 2.0 flow with PKCE implemented
- [ ] ASWebAuthenticationSession presents X login
- [ ] Authorization code exchanged for tokens
- [ ] Access token and refresh token returned
- [ ] Token refresh logic implemented
- [ ] Error handling for OAuth failures
- [ ] PKCE code verifier/challenge generated correctly

**Testing:**
- [ ] OAuth flow completes successfully
- [ ] Tokens are valid (test with X API call)
- [ ] Refresh token works after 2 hours
- [ ] Handles user cancellation gracefully
- [ ] Error states display user-friendly messages

**Estimate:** 2 hours

---

### Story 7.2: X API Service Layer (2.5 hours)

**As a developer, I want an X API service to fetch mentions and post replies so users can interact with X from BuzzBox.**

**Create: `buzzbox/Core/Models/XAccount.swift`**

```swift
import Foundation

/// Represents a connected X (Twitter) account
struct XAccount: Codable, Identifiable {
    let id: String  // X user ID
    let username: String  // @username
    let displayName: String
    let profileImageURL: String?
    let linkedAt: Date

    // OAuth tokens (stored in Keychain, not here)
    var accessToken: String? = nil
    var refreshToken: String? = nil
    var tokenExpiry: Date? = nil

    var isTokenExpired: Bool {
        guard let expiry = tokenExpiry else { return true }
        return Date() >= expiry
    }
}

/// Represents a mention or reply on X
struct XMention: Identifiable, Codable {
    let id: String  // Tweet ID
    let text: String
    let authorId: String
    let authorUsername: String
    let authorName: String
    let conversationId: String  // For threading
    let inReplyToTweetId: String?
    let createdAt: Date

    // Metadata
    let likeCount: Int?
    let replyCount: Int?
    let retweetCount: Int?
}
```

**Create: `buzzbox/Core/Services/XAPIService.swift`**

```swift
import Foundation

/// X (Twitter) API service for fetching mentions and posting replies
@MainActor
final class XAPIService: ObservableObject {

    // MARK: - Dependencies

    private let oauthService = XOAuthService()
    private let keychainService = KeychainService()

    // MARK: - Fetch User Profile

    /// Get authenticated user's profile
    func getUserProfile(accessToken: String) async throws -> XAccount {
        let url = URL(string: "https://api.x.com/2/users/me?user.fields=profile_image_url")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw XAPIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw XAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let json = try JSONDecoder().decode(UserResponse.self, from: data)

        return XAccount(
            id: json.data.id,
            username: json.data.username,
            displayName: json.data.name,
            profileImageURL: json.data.profile_image_url,
            linkedAt: Date()
        )
    }

    // MARK: - Fetch Mentions

    /// Fetch mentions for a user (includes replies to their tweets)
    func fetchMentions(for account: XAccount, maxResults: Int = 50) async throws -> [XMention] {
        // Ensure token is fresh
        try await refreshTokenIfNeeded(for: account)

        guard let accessToken = account.accessToken else {
            throw XAPIError.noAccessToken
        }

        var components = URLComponents(string: "https://api.x.com/2/users/\(account.id)/mentions")!
        components.queryItems = [
            URLQueryItem(name: "max_results", value: "\(maxResults)"),
            URLQueryItem(name: "tweet.fields", value: "created_at,conversation_id,in_reply_to_user_id,public_metrics"),
            URLQueryItem(name: "expansions", value: "author_id,referenced_tweets.id"),
            URLQueryItem(name: "user.fields", value: "username,name")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XAPIError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw XAPIError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            throw XAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let mentionsResponse = try JSONDecoder().decode(MentionsResponse.self, from: data)

        return mentionsResponse.data.map { tweet in
            let author = mentionsResponse.includes?.users?.first(where: { $0.id == tweet.author_id })

            return XMention(
                id: tweet.id,
                text: tweet.text,
                authorId: tweet.author_id,
                authorUsername: author?.username ?? "unknown",
                authorName: author?.name ?? "Unknown",
                conversationId: tweet.conversation_id,
                inReplyToTweetId: tweet.in_reply_to_user_id,
                createdAt: ISO8601DateFormatter().date(from: tweet.created_at) ?? Date(),
                likeCount: tweet.public_metrics?.like_count,
                replyCount: tweet.public_metrics?.reply_count,
                retweetCount: tweet.public_metrics?.retweet_count
            )
        }
    }

    // MARK: - Post Reply

    /// Post a reply to a tweet
    func postReply(text: String, inReplyTo tweetId: String, account: XAccount) async throws -> String {
        // Ensure token is fresh
        try await refreshTokenIfNeeded(for: account)

        guard let accessToken = account.accessToken else {
            throw XAPIError.noAccessToken
        }

        let url = URL(string: "https://api.x.com/2/tweets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "reply": [
                "in_reply_to_tweet_id": tweetId
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XAPIError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw XAPIError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 201 else {
            throw XAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let replyResponse = try JSONDecoder().decode(TweetCreateResponse.self, from: data)
        return replyResponse.data.id
    }

    // MARK: - Token Management

    private func refreshTokenIfNeeded(for account: XAccount) async throws {
        guard account.isTokenExpired else { return }

        guard let refreshToken = account.refreshToken else {
            throw XAPIError.noRefreshToken
        }

        let result = try await oauthService.refreshAccessToken(refreshToken: refreshToken)

        // Update tokens in Keychain
        try keychainService.store(result.accessToken, for: "x_access_token_\(account.id)")
        try keychainService.store(result.refreshToken, for: "x_refresh_token_\(account.id)")

        let expiry = Date().addingTimeInterval(TimeInterval(result.expiresIn))
        try keychainService.store(expiry.timeIntervalSince1970.description, for: "x_token_expiry_\(account.id)")
    }
}

// MARK: - Response Models

private struct UserResponse: Codable {
    struct UserData: Codable {
        let id: String
        let username: String
        let name: String
        let profile_image_url: String?
    }
    let data: UserData
}

private struct MentionsResponse: Codable {
    struct Tweet: Codable {
        let id: String
        let text: String
        let author_id: String
        let created_at: String
        let conversation_id: String
        let in_reply_to_user_id: String?
        let public_metrics: PublicMetrics?
    }

    struct PublicMetrics: Codable {
        let like_count: Int
        let reply_count: Int
        let retweet_count: Int
    }

    struct Includes: Codable {
        struct User: Codable {
            let id: String
            let username: String
            let name: String
        }
        let users: [User]?
    }

    let data: [Tweet]
    let includes: Includes?
}

private struct TweetCreateResponse: Codable {
    struct TweetData: Codable {
        let id: String
    }
    let data: TweetData
}

// MARK: - Errors

enum XAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case requestFailed(statusCode: Int)
    case rateLimitExceeded
    case noAccessToken
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from X API"
        case .unauthorized:
            return "X account authorization expired. Please reconnect."
        case .requestFailed(let code):
            return "X API request failed with status \(code)"
        case .rateLimitExceeded:
            return "X API rate limit exceeded. Please try again later."
        case .noAccessToken:
            return "No X access token found"
        case .noRefreshToken:
            return "No X refresh token found"
        }
    }
}
```

**Acceptance Criteria:**
- [ ] `fetchMentions()` returns user's mentions from X API
- [ ] Mentions include author info, conversation threading
- [ ] `postReply()` posts tweets to X successfully
- [ ] Token refresh happens automatically when expired
- [ ] Rate limit errors handled gracefully
- [ ] 401 errors trigger re-authentication
- [ ] Response models parse X API JSON correctly

**Testing:**
- [ ] Fetch mentions for test account
- [ ] Post reply to test tweet
- [ ] Token refresh works after 2 hours
- [ ] Rate limit error displays message
- [ ] Unauthorized error prompts reconnection

**Estimate:** 2.5 hours

---

### Story 7.3: Firebase Account Linking (1.5 hours)

**As a user, I want to link my X account to my BuzzBox account so I can use both authentication methods.**

**Create: `functions/src/x-auth.ts`**

```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';

interface XAuthRequest {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

interface XUserProfile {
  data: {
    id: string;
    username: string;
    name: string;
    profile_image_url?: string;
  };
}

/**
 * Generate Firebase custom token from X OAuth tokens
 * Used for "Sign in with X" flow
 */
export const generateCustomTokenFromX = onCall<XAuthRequest>(async (request) => {
  const { accessToken } = request.data;

  if (!accessToken) {
    throw new HttpsError('invalid-argument', 'accessToken is required');
  }

  try {
    // 1. Fetch X user profile
    const xProfile = await fetchXUserProfile(accessToken);
    const xUserId = xProfile.data.id;
    const xUsername = xProfile.data.username;

    // 2. Check if user already exists in Firebase
    let firebaseUser: admin.auth.UserRecord;
    try {
      firebaseUser = await admin.auth().getUserByProviderUid('twitter.com', xUserId);
    } catch (error) {
      // User doesn't exist - create new Firebase user
      firebaseUser = await admin.auth().createUser({
        uid: `x_${xUserId}`,
        displayName: xProfile.data.name,
        photoURL: xProfile.data.profile_image_url,
        providerToLink: {
          providerId: 'twitter.com',
          uid: xUserId,
        },
      });

      // Create user document in Firestore
      await admin.firestore().collection('users').doc(firebaseUser.uid).set({
        displayName: xProfile.data.name,
        xUsername: xUsername,
        xUserId: xUserId,
        authProviders: ['twitter.com'],
        type: xProfile.data.username === 'andrewsheim' ? 'creator' : 'fan',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 3. Update X account info in Firestore
    await admin.firestore()
      .collection('users')
      .doc(firebaseUser.uid)
      .set(
        {
          xAccounts: {
            [xUserId]: {
              xUserId,
              username: xUsername,
              displayName: xProfile.data.name,
              profileImageURL: xProfile.data.profile_image_url || null,
              linkedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
        },
        { merge: true }
      );

    // 4. Generate Firebase custom token
    const customToken = await admin.auth().createCustomToken(firebaseUser.uid);

    logger.info('Generated custom token for X user', {
      firebaseUid: firebaseUser.uid,
      xUserId,
      xUsername,
    });

    return {
      customToken,
      firebaseUid: firebaseUser.uid,
      xUserId,
      xUsername,
    };
  } catch (error) {
    logger.error('Failed to generate custom token from X', { error });
    throw new HttpsError('internal', 'Failed to authenticate with X');
  }
});

/**
 * Fetch X user profile using access token
 */
async function fetchXUserProfile(accessToken: string): Promise<XUserProfile> {
  const response = await fetch(
    'https://api.x.com/2/users/me?user.fields=profile_image_url',
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`X API error: ${response.status}`);
  }

  return await response.json();
}
```

**Update: `buzzbox/Core/Services/AuthService.swift`**

```swift
// Add X authentication methods

/// Sign in with X (Superhuman-style)
func signInWithX() async throws -> User {
    // 1. Get X OAuth tokens
    let oauthResult = try await xOAuthService.authenticate()

    // 2. Call Cloud Function to generate Firebase custom token
    let result = try await functions.httpsCallable("generateCustomTokenFromX")
        .call([
            "accessToken": oauthResult.accessToken,
            "refreshToken": oauthResult.refreshToken,
            "expiresIn": oauthResult.expiresIn
        ])

    guard let data = result.data as? [String: Any],
          let customToken = data["customToken"] as? String,
          let firebaseUid = data["firebaseUid"] as? String,
          let xUserId = data["xUserId"] as? String else {
        throw AuthError.invalidResponse
    }

    // 3. Sign into Firebase with custom token
    let authResult = try await Auth.auth().signIn(withCustomToken: customToken)

    // 4. Store X OAuth tokens in Keychain
    try KeychainService.store(oauthResult.accessToken, for: "x_access_token_\(xUserId)")
    try KeychainService.store(oauthResult.refreshToken, for: "x_refresh_token_\(xUserId)")

    let expiry = Date().addingTimeInterval(TimeInterval(oauthResult.expiresIn))
    try KeychainService.store(expiry.timeIntervalSince1970.description, for: "x_token_expiry_\(xUserId)")

    // 5. Fetch user profile
    try await fetchAndCacheUserProfile(uid: authResult.user.uid)

    return authResult.user
}

/// Link X account to existing Firebase user
func linkXAccount() async throws {
    guard let currentUser = Auth.auth().currentUser else {
        throw AuthError.notAuthenticated
    }

    // 1. Get X OAuth tokens
    let oauthResult = try await xOAuthService.authenticate()

    // 2. Get X user profile
    let xAccount = try await xAPIService.getUserProfile(accessToken: oauthResult.accessToken)

    // 3. Update Firestore with X account info
    try await db.collection("users").document(currentUser.uid).setData([
        "xAccounts": [
            xAccount.id: [
                "xUserId": xAccount.id,
                "username": xAccount.username,
                "displayName": xAccount.displayName,
                "profileImageURL": xAccount.profileImageURL as Any,
                "linkedAt": FieldValue.serverTimestamp()
            ]
        ]
    ], merge: true)

    // 4. Store X OAuth tokens in Keychain
    try KeychainService.store(oauthResult.accessToken, for: "x_access_token_\(xAccount.id)")
    try KeychainService.store(oauthResult.refreshToken, for: "x_refresh_token_\(xAccount.id)")

    let expiry = Date().addingTimeInterval(TimeInterval(oauthResult.expiresIn))
    try KeychainService.store(expiry.timeIntervalSince1970.description, for: "x_token_expiry_\(xAccount.id)")

    // 5. Refresh user profile
    try await fetchAndCacheUserProfile(uid: currentUser.uid)
}

/// Unlink X account
func unlinkXAccount(xUserId: String) async throws {
    guard let currentUser = Auth.auth().currentUser else { return }

    // Remove from Firestore
    try await db.collection("users").document(currentUser.uid).updateData([
        "xAccounts.\(xUserId)": FieldValue.delete()
    ])

    // Remove tokens from Keychain
    KeychainService.delete(key: "x_access_token_\(xUserId)")
    KeychainService.delete(key: "x_refresh_token_\(xUserId)")
    KeychainService.delete(key: "x_token_expiry_\(xUserId)")
}
```

**Acceptance Criteria:**
- [ ] Cloud Function generates Firebase custom token from X OAuth
- [ ] Creates new Firebase user if doesn't exist
- [ ] Links X account to existing Firebase user
- [ ] Stores X account metadata in Firestore
- [ ] OAuth tokens stored securely in Keychain (not Firestore!)
- [ ] Multi-provider auth supported (email + X)
- [ ] Unlink X account works correctly

**Testing:**
- [ ] Sign in with X creates new Firebase user
- [ ] Link X to existing email account works
- [ ] Multiple X accounts can be linked
- [ ] Unlink removes X account from Firestore + Keychain
- [ ] Tokens never appear in Firestore (security check)

**Estimate:** 1.5 hours

---

### Story 7.4: UI - Login Screen "Sign in with X" (45 min)

**As a user, I want to sign in with my X account so I can quickly access BuzzBox with my X identity.**

**Update: `buzzbox/Features/Auth/Views/LoginView.swift`**

```swift
VStack(spacing: 24) {
    // Logo
    Image("AppLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 120, height: 120)

    Text("Welcome to BuzzBox")
        .font(.title)
        .fontWeight(.bold)

    // Sign in with X (Superhuman-style)
    Button {
        Task {
            isLoading = true
            do {
                _ = try await authService.signInWithX()
                // Navigate to main app
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    } label: {
        HStack {
            Image(systemName: "xmark.app.fill")
            Text("Sign in with X")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    .disabled(isLoading)

    Divider()
        .overlay(Text("OR"))

    // Email sign in
    TextField("Email", text: $email)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .autocapitalization(.none)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)

    SecureField("Password", text: $password)
        .textContentType(.password)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)

    Button("Sign In with Email") {
        Task {
            isLoading = true
            do {
                try await authService.signInWithEmail(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.blue)
    .foregroundColor(.white)
    .cornerRadius(12)
    .disabled(email.isEmpty || password.isEmpty || isLoading)

    if isLoading {
        ProgressView()
    }
}
.padding()
.alert("Error", isPresented: $showError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(errorMessage)
}
```

**Acceptance Criteria:**
- [ ] "Sign in with X" button prominently displayed
- [ ] X button styled with X branding (black background, white text)
- [ ] Email sign in still available below
- [ ] Loading state shows during OAuth flow
- [ ] Error handling displays user-friendly messages
- [ ] Successful X login navigates to main app

**Testing:**
- [ ] Tap "Sign in with X" opens OAuth web view
- [ ] Completing X auth signs user into BuzzBox
- [ ] Error (e.g., user cancels) shows appropriate message
- [ ] Both X and email login work independently

**Estimate:** 45 min

---

### Story 7.5: UI - Settings "Connect X Account" (1 hour)

**As a user, I want to connect my X account from Settings so I can link X to my existing BuzzBox account.**

**Update: `buzzbox/Features/Settings/Views/ProfileView.swift`**

```swift
Section("Connected Accounts") {
    // Email (always present if using email auth)
    if let email = authService.currentUser?.email {
        HStack {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(email)
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if authService.currentUser?.isEmailVerified == true {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // X Accounts (can have multiple)
    ForEach(viewModel.xAccounts) { account in
        HStack {
            AsyncImage(url: URL(string: account.profileImageURL ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text("@\(account.username)")
                    .font(.body)
                Text("X Account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Disconnect", role: .destructive) {
                Task {
                    try? await viewModel.unlinkXAccount(account.id)
                }
            }
            .font(.caption)
        }
    }

    // Connect X button (if no accounts or want to add more)
    Button {
        Task {
            isConnectingX = true
            do {
                try await viewModel.connectXAccount()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isConnectingX = false
        }
    } label: {
        HStack {
            if isConnectingX {
                ProgressView()
            } else {
                Image(systemName: "xmark.app.fill")
                Text("Connect X Account")
            }
        }
    }
    .disabled(isConnectingX)
}
```

**Create: `buzzbox/Features/Settings/ViewModels/ProfileViewModel.swift` additions**

```swift
@Published var xAccounts: [XAccount] = []
@Published var isConnectingX = false

func loadXAccounts() async {
    guard let userId = authService.currentUser?.uid else { return }

    // Fetch from Firestore
    do {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data(),
              let xAccountsDict = data["xAccounts"] as? [String: [String: Any]] else {
            xAccounts = []
            return
        }

        // Parse X accounts
        xAccounts = xAccountsDict.compactMap { (xUserId, accountData) in
            guard let username = accountData["username"] as? String,
                  let displayName = accountData["displayName"] as? String else {
                return nil
            }

            // Load tokens from Keychain
            let accessToken = KeychainService.retrieve(key: "x_access_token_\(xUserId)")
            let refreshToken = KeychainService.retrieve(key: "x_refresh_token_\(xUserId)")
            let expiryString = KeychainService.retrieve(key: "x_token_expiry_\(xUserId)")
            let expiry = expiryString.flatMap { TimeInterval($0) }.map { Date(timeIntervalSince1970: $0) }

            return XAccount(
                id: xUserId,
                username: username,
                displayName: displayName,
                profileImageURL: accountData["profileImageURL"] as? String,
                linkedAt: (accountData["linkedAt"] as? Timestamp)?.dateValue() ?? Date(),
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenExpiry: expiry
            )
        }
    } catch {
        print("Failed to load X accounts: \(error)")
        xAccounts = []
    }
}

func connectXAccount() async throws {
    try await authService.linkXAccount()
    await loadXAccounts()
}

func unlinkXAccount(_ xUserId: String) async throws {
    try await authService.unlinkXAccount(xUserId: xUserId)
    await loadXAccounts()
}
```

**Acceptance Criteria:**
- [ ] "Connected Accounts" section shows email + X accounts
- [ ] "Connect X Account" button triggers OAuth flow
- [ ] Successfully linked X account appears in list
- [ ] Multiple X accounts can be connected
- [ ] "Disconnect" button removes X account
- [ ] Profile images display for X accounts
- [ ] Loading states show during connection

**Testing:**
- [ ] Connect first X account works
- [ ] Connect second X account works (multi-account)
- [ ] Disconnect X account removes it
- [ ] X accounts persist across app restarts
- [ ] Tokens load from Keychain correctly

**Estimate:** 1 hour

---

### Story 7.6: UI - Inbox Account Switcher (1.5 hours)

**As a user, I want to switch between BuzzBox and X inboxes so I can manage all my messages in one place.**

**Update: `buzzbox/Features/Inbox/Views/InboxView.swift`**

```swift
enum InboxSource: String, CaseIterable, Identifiable {
    case buzzbox = "BuzzBox"
    case x = "X"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .buzzbox: return "message.fill"
        case .x: return "xmark.app.fill"
        }
    }
}

struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @State private var selectedSource: InboxSource = .buzzbox
    @State private var selectedXAccount: XAccount?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Account Switcher (if X accounts connected)
                if !viewModel.xAccounts.isEmpty {
                    accountSwitcherBar
                }

                // Content
                Group {
                    switch selectedSource {
                    case .buzzbox:
                        buzzBoxInboxContent
                    case .x:
                        if let xAccount = selectedXAccount {
                            XMentionsView(account: xAccount)
                        } else {
                            Text("Select an X account")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(selectedSource == .buzzbox ? "Inbox" : "@\(selectedXAccount?.username ?? "X")")
            .toolbar {
                // ... existing toolbar items
            }
        }
        .task {
            await viewModel.loadXAccounts()
            if let firstX = viewModel.xAccounts.first {
                selectedXAccount = firstX
            }
        }
    }

    @ViewBuilder
    private var accountSwitcherBar: some View {
        VStack(spacing: 8) {
            // Source picker (BuzzBox vs X)
            Picker("Source", selection: $selectedSource) {
                ForEach(InboxSource.allCases) { source in
                    Label(source.rawValue, systemImage: source.icon)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // X Account picker (if X selected)
            if selectedSource == .x && viewModel.xAccounts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.xAccounts) { account in
                            XAccountChip(
                                account: account,
                                isSelected: selectedXAccount?.id == account.id
                            ) {
                                selectedXAccount = account
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var buzzBoxInboxContent: some View {
        // Existing BuzzBox inbox UI
        if viewModel.conversations.isEmpty {
            emptyStateView
        } else {
            conversationsList
        }
    }

    // ... rest of existing InboxView code
}

/// X Account selection chip
struct XAccountChip: View {
    let account: XAccount
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: account.profileImageURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())

                Text("@\(account.username)")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Segmented control switches between BuzzBox and X
- [ ] X account chips display when multiple X accounts exist
- [ ] Selected account highlighted
- [ ] Switching sources updates navigation title
- [ ] Account switcher only shows if X accounts connected
- [ ] Smooth transitions between sources

**Testing:**
- [ ] Tap BuzzBox shows BuzzBox conversations
- [ ] Tap X shows X mentions for selected account
- [ ] Switch between multiple X accounts works
- [ ] State persists during app use (doesn't reset)
- [ ] Works with 0, 1, or multiple X accounts

**Estimate:** 1.5 hours

---

### Story 7.7: UI - X Mentions View (2 hours)

**As a user, I want to see my X mentions and replies in a feed so I can respond to engagement on X.**

**Create: `buzzbox/Features/X/Views/XMentionsView.swift`**

```swift
import SwiftUI

struct XMentionsView: View {
    let account: XAccount

    @StateObject private var viewModel: XMentionsViewModel
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    init(account: XAccount) {
        self.account = account
        _viewModel = StateObject(wrappedValue: XMentionsViewModel(account: account))
    }

    var body: some View {
        Group {
            if isLoading && viewModel.mentions.isEmpty {
                loadingView
            } else if viewModel.mentions.isEmpty {
                emptyStateView
            } else {
                mentionsList
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            isLoading = true
            await viewModel.loadMentions()
            isLoading = false
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var mentionsList: some View {
        List {
            ForEach(viewModel.mentions) { mention in
                NavigationLink(destination: XMentionDetailView(mention: mention, account: account)) {
                    XMentionRowView(mention: mention)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading mentions...")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Mentions Yet",
            systemImage: "xmark.app",
            description: Text("When people reply to your tweets or mention you, they'll appear here.")
        )
    }
}

/// Row view for a single mention
struct XMentionRowView: View {
    let mention: XMention

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("@\(mention.authorUsername)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(mention.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(mention.text)
                .font(.body)
                .lineLimit(3)

            // Engagement metrics
            HStack(spacing: 16) {
                if let replies = mention.replyCount {
                    Label("\(replies)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let retweets = mention.retweetCount {
                    Label("\(retweets)", systemImage: "arrow.2.squarepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let likes = mention.likeCount {
                    Label("\(likes)", systemImage: "heart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Create: `buzzbox/Features/X/ViewModels/XMentionsViewModel.swift`**

```swift
import Foundation

@MainActor
final class XMentionsViewModel: ObservableObject {
    @Published var mentions: [XMention] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let account: XAccount
    private let xAPIService = XAPIService()

    init(account: XAccount) {
        self.account = account
    }

    func loadMentions() async {
        isLoading = true
        error = nil

        do {
            mentions = try await xAPIService.fetchMentions(for: account, maxResults: 50)
            mentions.sort { $0.createdAt > $1.createdAt }  // Newest first
        } catch {
            self.error = error
            print("Failed to load X mentions: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        await loadMentions()
    }
}
```

**Acceptance Criteria:**
- [ ] Displays X mentions/replies for selected account
- [ ] Shows author username, profile image, timestamp
- [ ] Shows engagement metrics (replies, retweets, likes)
- [ ] Pull-to-refresh loads new mentions
- [ ] Loading state shows while fetching
- [ ] Empty state when no mentions
- [ ] Tapping mention navigates to detail view
- [ ] Sorted by newest first

**Testing:**
- [ ] Mentions load on view appear
- [ ] Pull-to-refresh fetches new mentions
- [ ] Displays correctly with 0, 1, 10, 50+ mentions
- [ ] Handles rate limit errors gracefully
- [ ] Handles auth errors (expired token)

**Estimate:** 2 hours

---

### Story 7.8: UI - X Reply Composer (1.5 hours)

**As a user, I want to reply to X mentions from BuzzBox so I don't have to switch to the X app.**

**Create: `buzzbox/Features/X/Views/XMentionDetailView.swift`**

```swift
import SwiftUI

struct XMentionDetailView: View {
    let mention: XMention
    let account: XAccount

    @StateObject private var viewModel: XReplyViewModel
    @State private var replyText = ""
    @State private var isSending = false
    @State private var showSuccess = false

    init(mention: XMention, account: XAccount) {
        self.mention = mention
        self.account = account
        _viewModel = StateObject(wrappedValue: XReplyViewModel(mention: mention, account: account))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Original mention
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mentionCard

                    // Conversation thread (if available)
                    if !viewModel.conversationThread.isEmpty {
                        Divider()

                        Text("Conversation")
                            .font(.headline)

                        ForEach(viewModel.conversationThread) { tweet in
                            XMentionRowView(mention: tweet)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Reply composer
            replyComposer
        }
        .navigationTitle("Reply")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadConversationThread()
        }
        .alert("Reply Sent!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your reply was posted to X successfully.")
        }
    }

    @ViewBuilder
    private var mentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("@\(mention.authorUsername)")
                    .font(.headline)

                Spacer()

                Text(mention.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(mention.text)
                .font(.body)

            // Engagement
            HStack(spacing: 16) {
                if let replies = mention.replyCount {
                    Label("\(replies)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let retweets = mention.retweetCount {
                    Label("\(retweets)", systemImage: "arrow.2.squarepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let likes = mention.likeCount {
                    Label("\(likes)", systemImage: "heart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var replyComposer: some View {
        VStack(spacing: 12) {
            // Character counter
            HStack {
                Text("Replying to @\(mention.authorUsername)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(replyText.count)/280")
                    .font(.caption)
                    .foregroundStyle(replyText.count > 280 ? .red : .secondary)
            }

            // Text field
            TextField("Write your reply...", text: $replyText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)

            // Send button
            HStack {
                // AI Smart Replies button (reuse from Epic 6!)
                Button {
                    Task {
                        await viewModel.generateSmartReplies()
                    }
                } label: {
                    Label("AI Drafts", systemImage: "sparkles")
                        .font(.subheadline)
                }
                .disabled(viewModel.isGeneratingReplies)

                Spacer()

                Button {
                    Task {
                        isSending = true
                        do {
                            try await viewModel.sendReply(text: replyText)
                            replyText = ""
                            showSuccess = true
                        } catch {
                            // Show error
                        }
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Send")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(replyText.isEmpty || replyText.count > 280 || isSending)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
```

**Create: `buzzbox/Features/X/ViewModels/XReplyViewModel.swift`**

```swift
import Foundation

@MainActor
final class XReplyViewModel: ObservableObject {
    @Published var conversationThread: [XMention] = []
    @Published var isGeneratingReplies = false
    @Published var smartReplyDrafts: [String] = []

    private let mention: XMention
    private let account: XAccount
    private let xAPIService = XAPIService()
    private let aiService = AIService()

    init(mention: XMention, account: XAccount) {
        self.mention = mention
        self.account = account
    }

    func loadConversationThread() async {
        // Fetch conversation thread using conversation_id
        // This would require additional X API implementation
        // For now, just show the single mention
        conversationThread = []
    }

    func sendReply(text: String) async throws {
        _ = try await xAPIService.postReply(
            text: text,
            inReplyTo: mention.id,
            account: account
        )
    }

    func generateSmartReplies() async {
        isGeneratingReplies = true

        do {
            // Reuse AI service from Epic 6!
            // Create temporary conversation ID for X mention
            let tempConversationId = "x_\(mention.conversationId)"

            smartReplyDrafts = try await aiService.generateSmartReplies(
                conversationId: tempConversationId,
                messageText: mention.text
            )
        } catch {
            print("Failed to generate smart replies: \(error)")
            smartReplyDrafts = []
        }

        isGeneratingReplies = false
    }
}
```

**Acceptance Criteria:**
- [ ] Original mention displayed at top
- [ ] Reply text field with 280 character limit
- [ ] Character counter shows remaining characters
- [ ] Red counter when over 280 characters
- [ ] Send button disabled when empty or over limit
- [ ] Sending shows loading state
- [ ] Success confirmation after posting
- [ ] "AI Drafts" button generates smart replies (reuses Epic 6 AI!)
- [ ] Conversation thread displayed (if available)

**Testing:**
- [ ] Type reply and send successfully
- [ ] Character counter updates correctly
- [ ] Can't send empty reply
- [ ] Can't send reply over 280 chars
- [ ] AI smart replies work for X mentions
- [ ] Success message appears after sending
- [ ] Reply appears in X app

**Estimate:** 1.5 hours

---

### Story 7.9: Polish & Error Handling (1 hour)

**As a user, I want clear error messages and smooth UX so I understand what's happening with my X integration.**

**Error Scenarios to Handle:**

1. **OAuth Errors:**
   - User cancels login → "X login was cancelled"
   - Invalid credentials → "Failed to authenticate with X. Please try again."
   - Network error during OAuth → "Network error. Check your connection."

2. **API Errors:**
   - Rate limit (429) → "X API rate limit reached. Try again in 15 minutes."
   - Unauthorized (401) → "X authorization expired. Please reconnect your account."
   - Server error (500) → "X is experiencing issues. Try again later."

3. **Token Expiry:**
   - Auto-refresh fails → Prompt user to reconnect
   - Show reconnect button in Settings

4. **Multi-Account Edge Cases:**
   - Linking same X account twice → "This X account is already connected"
   - Maximum accounts (if limiting) → "Maximum X accounts reached"

**Polish Items:**

1. **Loading States:**
   - Skeleton loaders for mention feed
   - Spinner on OAuth button
   - "Sending..." on reply button

2. **Empty States:**
   - No mentions: ContentUnavailableView with helpful message
   - No X accounts: Prompt to connect in Settings

3. **Success Feedback:**
   - Toast after connecting X account
   - Haptic feedback on successful reply
   - Checkmark animation after sending

4. **Animations:**
   - Smooth account switcher transitions
   - Mention row selection highlight
   - Reply sent animation

**Create: `buzzbox/Core/Views/Components/XErrorView.swift`**

```swift
import SwiftUI

struct XErrorView: View {
    let error: XAPIError
    let retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorMessage)
        } actions: {
            if let retryAction {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }

            if error == .unauthorized {
                NavigationLink("Reconnect X Account") {
                    ProfileView()
                }
            }
        }
    }

    private var errorMessage: String {
        switch error {
        case .rateLimitExceeded:
            return "You've reached X's rate limit. Please try again in 15 minutes."
        case .unauthorized:
            return "Your X authorization has expired. Please reconnect your account."
        case .invalidResponse, .requestFailed:
            return "Failed to connect to X. Please check your internet connection."
        case .noAccessToken, .noRefreshToken:
            return "X account not properly configured. Please reconnect."
        }
    }
}
```

**Acceptance Criteria:**
- [ ] All error scenarios handled gracefully
- [ ] Loading states show during async operations
- [ ] Empty states provide helpful guidance
- [ ] Success feedback confirms actions
- [ ] Animations enhance user experience
- [ ] Rate limit errors show time to retry
- [ ] Unauthorized errors prompt reconnection
- [ ] Network errors suggest checking connection

**Testing:**
- [ ] Simulate rate limit error (mock)
- [ ] Test token expiry handling
- [ ] Cancel OAuth flow midway
- [ ] Try connecting same account twice
- [ ] Test with no internet connection
- [ ] Verify all loading states appear
- [ ] Check empty states display correctly

**Estimate:** 1 hour

---

## ⏱️ Time Breakdown

| Story | Description | Time |
|-------|-------------|------|
| 7.0 | X Developer Account & API Setup | 1 hr |
| 7.1 | X OAuth Service Layer | 2 hrs |
| 7.2 | X API Service Layer | 2.5 hrs |
| 7.3 | Firebase Account Linking | 1.5 hrs |
| 7.4 | UI - Login "Sign in with X" | 45 min |
| 7.5 | UI - Settings "Connect X Account" | 1 hr |
| 7.6 | UI - Inbox Account Switcher | 1.5 hrs |
| 7.7 | UI - X Mentions View | 2 hrs |
| 7.8 | UI - X Reply Composer | 1.5 hrs |
| 7.9 | Polish & Error Handling | 1 hr |
| **TOTAL** | | **~14.75 hours** |

---

## 🗄️ Data Model Changes

### XAccount Model (New)
```swift
struct XAccount: Codable, Identifiable {
    let id: String  // X user ID
    let username: String
    let displayName: String
    let profileImageURL: String?
    let linkedAt: Date

    // Tokens (Keychain only, not in model)
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiry: Date?
}
```

### XMention Model (New)
```swift
struct XMention: Identifiable, Codable {
    let id: String  // Tweet ID
    let text: String
    let authorId: String
    let authorUsername: String
    let authorName: String
    let conversationId: String
    let inReplyToTweetId: String?
    let createdAt: Date
    let likeCount: Int?
    let replyCount: Int?
    let retweetCount: Int?
}
```

### Firestore User Document (Updated)
```
users/{userId}/
  email: String (existing)
  displayName: String (existing)
  authProviders: ["password", "twitter.com"]  // NEW: multi-provider
  xAccounts: {  // NEW
    "{xUserId}": {
      xUserId: String
      username: String
      displayName: String
      profileImageURL: String?
      linkedAt: Timestamp
    }
  }
```

### Keychain Storage (New)
```
Keys per X account:
- x_access_token_{xUserId}
- x_refresh_token_{xUserId}
- x_token_expiry_{xUserId}
```

---

## 🔒 Security Considerations

### OAuth Token Storage
- ✅ **Keychain (iOS):** Store access_token, refresh_token
- ❌ **Firestore:** NEVER store tokens in Firestore
- ✅ **Cloud Functions:** Use Firebase secrets for API keys

### API Rate Limiting
- Basic tier: 10,000 requests/month
- Implement exponential backoff for 429 errors
- Cache mentions locally (reduce API calls)

### Multi-Account Security
- Each X account has separate Keychain entries
- Tokens never shared between accounts
- Firestore rules prevent unauthorized access

---

## ✅ Success Criteria

**Epic 7 is complete when:**

### Functional Requirements
- ✅ Users can sign in with X (Superhuman-style)
- ✅ Users can connect X to existing email account
- ✅ Multiple X accounts supported per user
- ✅ Inbox shows BuzzBox + X tabs with account switcher
- ✅ X mentions/replies display in feed
- ✅ Users can reply to X mentions from app
- ✅ AI smart replies work for X (reuses Epic 6)

### Technical Requirements
- ✅ OAuth 2.0 flow with PKCE implemented
- ✅ X API service fetches mentions and posts replies
- ✅ Firebase account linking (multi-provider auth)
- ✅ Tokens stored securely in Keychain
- ✅ Cloud Function generates custom tokens
- ✅ Token refresh handled automatically
- ✅ Rate limiting handled gracefully

### UX Requirements
- ✅ "Sign in with X" on login screen
- ✅ "Connect X Account" in Settings
- ✅ Account switcher in InboxView
- ✅ X mentions display like messages
- ✅ Reply composer with 280 char limit
- ✅ Loading states for all async operations
- ✅ Error handling with user-friendly messages
- ✅ Success feedback for actions

---

## 🚨 Risks & Mitigations

### Risk 1: X API Pricing ($100/month minimum)
**Impact:** Ongoing monthly cost
**Mitigation:**
- Start with Basic tier ($100/month)
- Monitor usage closely
- Implement caching to reduce API calls
- Consider as investment in multi-platform vision
- Only fetch mentions when user actively viewing

### Risk 2: OAuth Complexity
**Impact:** Authentication bugs, token management issues
**Mitigation:**
- Follow X OAuth 2.0 docs exactly
- Test token refresh thoroughly
- Handle all error scenarios
- Use proven ASWebAuthenticationSession
- Store tokens securely in Keychain

### Risk 3: Firebase Multi-Provider Auth
**Impact:** Account linking conflicts, duplicate accounts
**Mitigation:**
- Check for existing accounts before creating new ones
- Implement email verification for conflicts
- Allow manual account merging
- Clear error messages for conflicts

### Risk 4: Rate Limiting (10K tweets/month)
**Impact:** Users hitting limits, degraded experience
**Mitigation:**
- Cache mentions locally (reduce fetches)
- Only fetch on pull-to-refresh (not auto)
- Show rate limit errors clearly
- Upgrade to Pro tier if needed ($5K/month)

### Risk 5: Token Expiry (2 hour lifespan)
**Impact:** Auth failures mid-session
**Mitigation:**
- Automatic token refresh on API calls
- Refresh proactively before expiry
- Graceful fallback to re-auth
- Clear messaging to user

---

## 📦 Implementation Order

### Phase 1: Authentication Foundation (4.5 hours)
1. X Developer account setup (Story 7.0)
2. OAuth service layer (Story 7.1)
3. Firebase account linking (Story 7.3)
4. Test OAuth flow end-to-end

### Phase 2: X API Integration (2.5 hours)
5. X API service layer (Story 7.2)
6. Test fetching mentions and posting replies
7. Verify token refresh works

### Phase 3: UI - Authentication (1.75 hours)
8. Login screen "Sign in with X" (Story 7.4)
9. Settings "Connect X Account" (Story 7.5)
10. Test both auth flows

### Phase 4: UI - Inbox & Mentions (5 hours)
11. Inbox account switcher (Story 7.6)
12. X mentions view (Story 7.7)
13. X reply composer (Story 7.8)
14. Test complete X workflow

### Phase 5: Polish (1 hour)
15. Error handling & polish (Story 7.9)
16. End-to-end testing
17. Documentation updates

**Total: ~14.75 hours**

---

## 📚 References

- **X API Docs:** https://developer.x.com/en/docs
- **OAuth 2.0 PKCE:** https://developer.x.com/en/docs/authentication/oauth-2-0/authorization-code
- **Firebase Auth Multi-Provider:** https://firebase.google.com/docs/auth/ios/account-linking
- **ASWebAuthenticationSession:** https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
- **Epic 6:** AI-Powered Creator Inbox (for AI smart replies integration)

---

## 🎬 Next Steps

**After Epic 7 Completion:**
1. ✅ Multi-platform inbox operational (BuzzBox + X)
2. ✅ AI features extended to X (smart replies)
3. 🚀 **Future:** Add Instagram, TikTok, Discord integrations
4. 🚀 **Future:** Unified analytics across platforms
5. 🚀 **Future:** Cross-platform scheduling

**Strategic Value:**
- Positions BuzzBox as **unified creator communication hub**
- Differentiates from single-platform apps
- Aligns with Superhuman's multi-account philosophy
- Foundation for additional platform integrations

---

**Epic Status:** 🟢 Ready to Implement
**Blockers:** X Developer account approval (1-2 days), API tier subscription ($100/month)
**Risk Level:** Medium (OAuth complexity, ongoing costs)
**Strategic Value:** HIGH - Multi-platform differentiation

**Recommendation: Implement after Epic 6 is complete. This transforms BuzzBox from a single-platform messaging app into a true creator inbox tool.**
