# Security Architecture

### 8.1 Security Layers

**Layer 1: Transport Security**
- All network traffic over TLS/SSL
- Certificate pinning (optional future enhancement)

**Layer 2: Authentication**
- Firebase Auth with email/password
- JWT tokens for API authentication
- Token refresh flow (tokens expire after 1 hour)
- Tokens stored in iOS Keychain (secure enclave)

**Layer 3: Authorization**
- Firestore Security Rules enforce access control
- Users can only read/write their own data
- Conversation access requires participant verification
- Cloud Functions validate user permissions

**Layer 4: Data Security**
- Keychain for auth tokens
- SwiftData encryption at rest (iOS built-in)
- Firestore encryption at rest (Google managed)

**Layer 5: API Key Security**
- OpenAI/Supermemory API keys NEVER in iOS app
- Keys stored in Cloud Functions environment variables
- Keys rotated quarterly
- Usage monitored for anomalies

### 8.2 Input Sanitization

- Limit message length (10,000 characters)
- Strip control characters
- Validate email format
- Validate password strength (8+ characters)
- Sanitize AI prompts to prevent injection attacks

### 8.3 Privacy Considerations

- Messages stored locally in SwiftData (encrypted by iOS)
- Supermemory storage opt-in (user can disable)
- Clear data deletion (account deletion removes all Firestore data)
- GDPR compliant (data export/deletion on request)
