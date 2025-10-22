# Data Architecture

### 4.1 Core Data Models

**User**
- id, email, displayName, photoURL
- aiPreferences (toggles for AI features)
- faqs (FAQ library for creator)
- createdAt, updatedAt

**Conversation**
- id, participantIDs, participants
- lastMessage, unreadCount
- isPinned, isMuted
- createdAt, updatedAt

**Message**
- id, conversationID, senderID, sender
- text, attachments, status
- AI Metadata: category, sentiment, opportunityScore, faqMatch, smartReplyDraft
- Sync Metadata: syncStatus, retryCount
- readBy (read receipts)
- createdAt, updatedAt

**Attachment**
- id, type (image/video/audio/document)
- url (remote), localURL, thumbnailURL
- fileSize, mimeType, uploadStatus

### 4.2 SwiftData Schema

SwiftData uses `@Model` classes for local persistence:

- **UserEntity**: Local user data and preferences
- **ConversationEntity**: Conversation metadata, relationships to messages
- **MessageEntity**: Message content, AI metadata, sync status
- **AttachmentEntity**: Media files with upload tracking
- **FAQEntity**: FAQ library for auto-responder feature

**Relationships:**
- UserEntity → [ConversationEntity] (one-to-many)
- UserEntity → [FAQEntity] (one-to-many)
- ConversationEntity → [MessageEntity] (one-to-many, cascade delete)
- MessageEntity → [AttachmentEntity] (one-to-many, cascade delete)

**Implementation Details:**
📖 See [SwiftData Implementation Guide](./swiftdata-implementation-guide.md) for:
- Complete @Model entity code with all properties and relationships
- ModelContainer setup in App.swift
- @Query examples in ViewModels and Views
- Background sync coordinator patterns

### 4.3 Firestore Schema

**Collections Structure:**

```
/users/{userId}
  - User profile data
  - AI preferences
  - FAQ library

/users/{userId}/conversations/{conversationId}
  - User's conversation metadata
  - Last message preview
  - Unread count

/conversations/{conversationId}
  - Shared conversation data
  - participantIDs

/conversations/{conversationId}/messages/{messageId}
  - Message content
  - AI metadata (category, sentiment, etc.)
  - Read receipts

/conversations/{conversationId}/participants/{userId}
  - Participant join timestamp
  - Last read message ID
  - Notification preferences
```

**Security Rules:**
- Users can only read/write their own data
- Conversation access requires being a participant
- Messages readable only by conversation participants
- Server-side validation via Cloud Functions

### 4.4 SwiftData ↔ Firestore Sync Strategy

**Write Path (Optimistic UI):**
1. User action (send message) → Write to SwiftData immediately
2. Display message instantly in UI (optimistic update)
3. Mark message as `syncStatus: .pending`
4. Attempt Firestore sync in background
5. Update `syncStatus: .synced` on success, `.failed` on error

**Read Path (Cache-First):**
1. Fetch from SwiftData first (instant, works offline)
2. If online, fetch from Firestore in background
3. Update SwiftData cache with Firestore data
4. SwiftData change notifications trigger UI updates

**Conflict Resolution:** Last-write-wins based on server timestamp.

**Offline Queue:**
- Messages with `syncStatus: .pending` are queued
- BackgroundSyncService monitors network status
- When online, process queue with exponential backoff retries
- Max 3 retry attempts before marking as failed
