# Epic 3: Group Chat

**Phase:** Day 2-3 (Extended Messaging)
**Priority:** P1 (High - Core Feature)
**Estimated Time:** 3-4 hours
**Epic Owner:** Development Team Lead
**Dependencies:** Epic 2 (One-on-One Chat Infrastructure)

---

## ✅ CODEBASE READINESS (Updated: 2025-10-21)

**All prerequisite fixes have been applied to the codebase:**
- ✅ `ConversationEntity` extended with `adminUserIDs: [String]` and `groupPhotoURL`
- ✅ `MessageEntity` extended with `isSystemMessage: Bool` and `readBy: [String: Date]`
- ✅ RTDB rules updated with group validation (admin permissions, participant limits, system messages)
- ✅ `ConversationService.syncConversation()` syncs all group fields to RTDB
- ✅ Storage rules added for `/group_photos/{groupId}/` path
- ✅ `StorageService.uploadGroupPhoto()` method added for group photo uploads

**Security Enhancements:**
- ✅ Only admins can modify `groupName`, `groupPhotoURL`, and `participantList` (enforced by RTDB rules)
- ✅ Participant limits enforced: min 2, max 256 (RTDB validation)
- ✅ System messages validated: `senderID` must be "system" if `isSystemMessage == true`
- ✅ Read receipts support timestamps: `readBy: { "userID": timestamp }`

**Implementation Ready:** This epic is now ready for Story 3.1 implementation.

---

## Overview

Extend the one-on-one messaging infrastructure to support group conversations with multiple participants. Includes group creation, participant management, group info editing, and optimized message delivery for multi-user scenarios.

---

## What This Epic Delivers

- ✅ Create group conversations with multiple participants
- ✅ Group info screen (name, photo, participant list)
- ✅ Add/remove participants from groups
- ✅ Group admin permissions (creator is admin)
- ✅ Leave group functionality
- ✅ Group name and photo editing
- ✅ Participant typing indicators ("Alice and Bob are typing...")
- ✅ Read receipts showing who read each message
- ✅ Group message delivery optimized for multiple recipients
- ✅ **Read receipts for one-on-one conversations** (Story 3.10)
- ✅ **Image attachment support in messages** (Stories 3.11-3.12)

---

[... Keep all existing content from lines 51-1467 exactly as is ...]

---

## MVP Completion Stories (Added: 2025-10-22)

**Context:** The following three stories address gaps identified during Product Owner review against core messaging requirements. All three are **P0 (MVP Blockers)** and must be completed before TestFlight deployment.

**Total Additional Time:** 2 hours 15 minutes

---

### Story 3.10: Read Receipts for One-on-One Conversations
**As a user, I want to see read receipts in 1:1 chats so I know when my message has been read.**

**Priority:** P0 (MVP Blocker)
**Estimated Time:** 30 minutes
**Complexity:** Low (extend existing group read receipt infrastructure)

**Gap Analysis:**
- ❌ **Current:** Read receipts ONLY work in groups (`MessageBubbleView:37` requires `conversation.isGroup`)
- ✅ **Expected:** WhatsApp-style double blue checkmark for all conversations (1:1 and groups)
- 📊 **Impact:** Users cannot see if their 1:1 messages have been read

**Acceptance Criteria:**
- [ ] Double checkmark turns blue when recipient reads message (1:1 chats)
- [ ] Read status updates in real-time (RTDB listener)
- [ ] Read status persists across app restarts (SwiftData)
- [ ] Tapping read checkmark shows "Message Info" sheet with timestamp
- [ ] Works offline: read status queued and synced when online
- [ ] VoiceOver announces "Read" status for accessibility

**Technical Tasks:**

1. **Update MessageBubbleView.swift** (1 line change at line 37):
   ```swift
   /// Check if read receipts can be shown (own messages in all conversations)
   private var canShowReadReceipts: Bool {
       isFromCurrentUser && !message.isSystemMessage
       // ✅ Removed: && conversation.isGroup
   }
   ```

2. **Update ReadReceiptsView.swift** (~40 lines):
   - Add `conversation: ConversationEntity` parameter
   - Create `oneOnOneReadReceiptView` for single recipient
   - Show "Message Info" with Sent/Delivered/Read timestamps
   - Format:
     - Sent: [timestamp]
     - Delivered: ✓ or "Pending"
     - Read: [timestamp] or "Not yet"

3. **Verify MessageService.swift**:
   - Existing `listenToReadReceipts()` already works for 1:1 and groups
   - Verify RTDB rules allow `/messages/{conversationID}/{messageID}/readBy/{userID}` writes

4. **Verify MessageThreadView.swift** (line 227):
   - Existing `markVisibleMessagesAsRead()` should work for 1:1
   - Writes to `message.readBy[currentUserID] = Date()`
   - Syncs to RTDB via `MessageService.shared.markMessageAsRead()`

**Testing Standards:**

**Manual Testing:**
- [ ] User A sends message to User B (1:1 chat)
- [ ] User A sees single checkmark (sent)
- [ ] User B opens conversation
- [ ] User A sees double gray checkmark (delivered)
- [ ] User B scrolls to message (marks as read)
- [ ] User A sees double BLUE checkmark (read)
- [ ] User A taps checkmark → "Message Info" sheet shows read timestamp
- [ ] Offline test: B reads while A is offline → sync when A reconnects

**Regression Testing:**
- [ ] Group read receipts still work (multi-recipient)
- [ ] Long press in groups shows "Read By" list
- [ ] System messages don't show read receipts

**References:**
- Story 3.6 (Group Read Receipts) - extend to 1:1
- UX Design Doc Section 4.3 (Message Thread - Read Receipts)
- Implementation Plan: See detailed breakdown above

---

### Story 3.11: Send Image Attachments in Messages
**As a user, I want to attach images to messages so I can share photos with friends.**

**Priority:** P0 (MVP Blocker)
**Estimated Time:** 60 minutes
**Complexity:** Medium (UI + backend integration)

**Gap Analysis:**
- ✅ **Exists:** AttachmentEntity model, StorageService.uploadImage()
- ❌ **Missing:** MessageComposerView has NO photo button
- ❌ **Missing:** No UI to select/preview images
- 📊 **Impact:** Users cannot send photos (core messaging feature missing)

**Acceptance Criteria:**
- [ ] "+" button in MessageComposerView opens iOS photo picker
- [ ] User selects photo from library (NSPhotoLibraryUsageDescription permission)
- [ ] Selected photo shows thumbnail preview with file size
- [ ] User can remove photo before sending
- [ ] Photo uploads to Firebase Storage with progress indicator (0-100%)
- [ ] Message sends with image attachment after upload completes
- [ ] Attachment persists in SwiftData (offline queue)
- [ ] Failed uploads show retry button with specific error message
- [ ] Photos compressed before upload (max 2MB, JPEG quality 0.8)
- [ ] Works offline: uploads queue and process when online
- [ ] Supports JPG and PNG formats

**Technical Tasks:**

1. **Update MessageComposerView.swift** (~80 lines):
   - Add `@Binding var selectedImage: UIImage?` parameter
   - Add `@State private var showImagePicker = false`
   - Add "+" button (left of text field) to open photo picker
   - Add `imagePreviewView()` showing thumbnail + file size + X button
   - Update `isSendDisabled` logic: allow send if text OR image present
   - Add `.sheet(isPresented: $showImagePicker) { ImagePicker(image: $selectedImage) }`

2. **Update MessageThreadView.swift** (~15 lines):
   - Add `@State private var selectedImage: UIImage?`
   - Pass `selectedImage: $selectedImage` to MessageComposerView
   - Update `sendMessage()` to accept optional image parameter
   - Clear `selectedImage = nil` after sending (optimistic UI)

3. **Update MessageThreadViewModel.swift** (~120 lines):
   - Update `sendMessage(text:image:)` signature to accept `UIImage?`
   - Create AttachmentEntity if image provided
   - Save image to temporary directory: `saveImageToTemporaryDirectory()`
   - Insert AttachmentEntity into SwiftData with `uploadStatus: .pending`
   - Sync message text to RTDB immediately (fast path)
   - Background task: `uploadAttachment()` to Firebase Storage
   - Update RTDB with attachment URL after upload completes
   - Handle upload failures: mark attachment as failed, show retry

4. **Update MessageService.swift** (~25 lines):
   - Add `updateMessageAttachment()` method
   - Writes to RTDB: `/messages/{conversationID}/{messageID}/attachment`
   - Payload: `{ url: string, type: "image", uploadedAt: timestamp }`
   - Update RTDB listener to sync attachment URLs back to SwiftData

**Testing Standards:**

**Manual Testing:**
- [ ] Tap "+" button → iOS photo picker opens
- [ ] Select photo → thumbnail appears with file size
- [ ] Tap X on thumbnail → photo removed
- [ ] Send photo only (no text) → message sends with "[Photo]" placeholder
- [ ] Send text + photo → both visible in message
- [ ] Slow network → upload progress bar shows 0-100%
- [ ] Turn off WiFi mid-upload → upload fails, retry button shows
- [ ] Tap retry → upload resumes and completes
- [ ] Offline test: attach photo, turn off WiFi, send → queues locally
- [ ] Turn on WiFi → attachment uploads automatically

**Integration Testing:**
- [ ] Cross-device: Device A sends photo → Device B receives
- [ ] Large photo (5MB+) → compresses to <2MB before upload
- [ ] Corrupt image file → error toast with specific message
- [ ] Network timeout → retry with exponential backoff
- [ ] Low storage space → warning alert before upload

**References:**
- PRD Epic 2: One-on-One Chat (Story 2.4 - Image Attachments)
- Existing: GroupCreationView.swift (ImagePicker usage pattern)
- Existing: StorageService.uploadImage()
- Implementation Plan: See detailed breakdown above

---

### Story 3.12: Display Image Attachments in Message Bubbles
**As a user, I want to see images in message bubbles so I can view shared photos.**

**Priority:** P0 (MVP Blocker)
**Estimated Time:** 45 minutes
**Complexity:** Medium (UI rendering + interaction)

**Gap Analysis:**
- ❌ **Current:** MessageBubbleView only renders `message.text` (line 82)
- ❌ **Current:** Ignores `message.attachments` array entirely
- 📊 **Impact:** Even if backend supported images, UI cannot display them

**Acceptance Criteria:**
- [ ] Image attachments render in message bubble above text
- [ ] Images load asynchronously with "Loading..." placeholder
- [ ] Tap image opens full-screen ImageViewerView
- [ ] Images scale proportionally (max width 75% of screen, max height 300pt)
- [ ] Failed image loads show error icon + "Retry Download" button
- [ ] Long press image (own messages) shows read receipts sheet
- [ ] Upload progress overlay shows percentage (0-100%) while uploading
- [ ] Supports offline cached images (loads from localURL if url unavailable)
- [ ] Full-screen viewer supports pinch-to-zoom (1x-4x), swipe-down to dismiss

**Technical Tasks:**

1. **Update MessageBubbleView.swift** (~120 lines):
   - Add `@State private var showImageViewer = false`
   - Add `@State private var imageToView: String?`
   - Update `regularMessageView` to render images before text
   - Create `imageAttachmentView()` method:
     - AsyncImage with loading/success/failure states
     - Loading: Gray placeholder + ProgressView
     - Success: Image with maxWidth 75%, maxHeight 300, rounded corners
     - Failure: Error icon + retry button
   - Add `.onTapGesture { showImageViewer = true }` to image
   - Add `.fullScreenCover(isPresented: $showImageViewer) { ImageViewerView() }`
   - Show upload progress overlay if `attachment.uploadStatus == .uploading`

2. **Create ImageViewerView.swift** (NEW FILE, ~110 lines):
   - Full-screen black background
   - AsyncImage with loading/error states
   - Close button (top-right X)
   - Pinch-to-zoom gesture (1x-4x zoom range)
   - Double-tap to reset zoom
   - Swipe down gesture to dismiss
   - `.statusBar(hidden: true)` for immersive viewing

3. **Update MessageThreadViewModel.swift** (~15 lines):
   - Update `retryFailedMessage()` to handle attachment retries
   - If message has failed attachment, call `uploadAttachment()` again
   - Reset attachment status: `uploadStatus = .pending`

**Testing Standards:**

**Manual Testing:**
- [ ] Receive message with image → image renders in bubble
- [ ] Image loads async → placeholder shows → image appears
- [ ] Tap image → full-screen viewer opens
- [ ] In viewer: pinch to zoom → scales 1x-4x
- [ ] In viewer: double-tap → resets zoom to 1x
- [ ] In viewer: swipe down → dismisses to chat
- [ ] In viewer: tap X button → dismisses to chat
- [ ] Upload progress: send image on slow network → shows 0-100% overlay
- [ ] Failed load: broken URL → error icon + "Retry Download" button
- [ ] Long press image (own message) → read receipts sheet opens

**Accessibility Testing:**
- [ ] VoiceOver: "Image attachment. Tap to view full screen."
- [ ] Dynamic Type: Image scales with text size preferences
- [ ] High Contrast: Image borders visible in high contrast mode

**Edge Cases:**
- [ ] Very tall image (portrait 9:16) → constrains to maxHeight 300
- [ ] Very wide image (panorama 3:1) → constrains to maxWidth 75%
- [ ] Corrupt image file → shows error state with retry
- [ ] Offline cached image → loads from localURL
- [ ] Multiple attachments → only first shown (future: carousel)

**References:**
- UX Design Doc Section 4.3 (Message Thread - Media Support)
- Existing: AsyncImage patterns in GroupInfoView, ConversationRowView
- Implementation Plan: See detailed breakdown above

---

## Updated Time Estimates

| Story | Original Est. | Revised Est. | Notes |
|-------|--------------|--------------|-------|
| 3.1 Create Group Conversation | 60 mins | 60 mins | ✅ Complete |
| 3.2 Group Info Screen | 50 mins | 50 mins | ✅ Complete |
| 3.3 Add and Remove Participants | 50 mins | 50 mins | ✅ Complete |
| 3.4 Edit Group Name and Photo | 35 mins | 35 mins | ✅ Complete |
| 3.5 Group Typing Indicators | 30 mins | 30 mins | ✅ Complete |
| 3.6 Group Read Receipts | 45 mins | 45 mins | ✅ Complete |
| 3.7 Group Message Notifications | 45 mins | 45 mins | ✅ Complete |
| **3.10 Read Receipts for 1:1** | - | **30 mins** | **NEW (MVP)** |
| **3.11 Send Image Attachments** | - | **60 mins** | **NEW (MVP)** |
| **3.12 Display Image Attachments** | - | **45 mins** | **NEW (MVP)** |
| **Epic 3 Total** | **5-6 hours** | **7-8 hours** | **+2.25 hours** |

---

## Updated Implementation Order

**Phase 1: Core Group Chat (Complete)** ✅
1. Story 3.1 (Create Group) - Foundation
2. Story 3.7 (Group Notifications) - Critical path
3. Story 3.2 (Group Info) - Management UI
4. Story 3.3 (Add/Remove Participants) - Core management
5. Story 3.4 (Edit Group Info) - Customization
6. Story 3.5 (Typing Indicators) - Real-time polish
7. Story 3.6 (Group Read Receipts) - Advanced feature

**Phase 2: MVP Completion (Required for TestFlight)** 🔴
8. **Story 3.10 (Read Receipts for 1:1)** - Quick win, extends existing code (30 min)
9. **Story 3.11 (Send Image Attachments)** - Core feature, backend integration (60 min)
10. **Story 3.12 (Display Image Attachments)** - Completes image flow (45 min)

**Critical Path:** Stories 3.10-3.12 are **MVP blockers** and must be completed before TestFlight deployment to meet core messaging feature parity.

---

## Success Criteria

**Epic 3 is complete when:**
- ✅ Users can create group conversations with 2+ participants
- ✅ Group info screen shows participants and settings
- ✅ Admins can add/remove participants
- ✅ Admins can edit group name and photo
- ✅ Users can leave groups
- ✅ Typing indicators show multiple users
- ✅ Read receipts show who read messages (groups)
- ✅ All group operations sync in real-time
- ✅ **Read receipts work in 1:1 conversations** (Story 3.10)
- ✅ **Users can send image attachments** (Story 3.11)
- ✅ **Users can view images in message bubbles** (Story 3.12)

---

## References

- **SwiftData Implementation Guide**: `docs/swiftdata-implementation-guide.md`
- **Architecture Doc**: `docs/architecture.md` (Section 5: Data Flow)
- **UX Design Doc**: `docs/ux-design.md` (Section 3.3: Group Info)
- **PRD**: `docs/prd.md` (Epic 3: Group Chat)
- **Implementation Plans**: Stories 3.10-3.12 detailed plans included above

---

## Post-MVP Enhancements (Deferred)

The following features were identified during Epic 3 planning but deferred to post-MVP to maintain sprint velocity:

### Story 3.8: Mute Group Notifications
**Priority:** P2 (Medium)
**Estimated Time:** 30 minutes

**Features:**
- [ ] User can mute specific groups from Group Info screen
- [ ] Muted groups don't send FCM notifications (Cloud Functions check)
- [ ] Unmute option in Group Info screen
- [ ] Mute duration options (1 hour, 8 hours, 1 day, 1 week, forever)
- [ ] Muted groups show mute icon in ConversationListView
- [ ] Mute status stored in Firestore `/users/{userID}/mutedConversations/{conversationID}`

**Technical Notes:**
- Cloud Functions must check mute status before sending FCM:
  ```typescript
  const mutedDoc = await firestore
    .collection('users')
    .doc(recipientID)
    .collection('mutedConversations')
    .doc(conversationID)
    .get();

  if (mutedDoc.exists && mutedDoc.data()?.mutedUntil > Date.now()) {
    // Skip notification for this recipient
    continue;
  }
  ```

---

### Story 3.9: Notification Grouping & Rich Actions
**Priority:** P3 (Low)
**Estimated Time:** 60 minutes

**Features:**
- [ ] Multiple messages from same group stack into single expandable notification
- [ ] Notification shows: "3 new messages in Family Group"
- [ ] Inline reply from notification (iOS notification actions)
- [ ] Mark as Read action in notification
- [ ] Multi-device notification deduplication (clear on one device = clear on all)

**Technical Notes:**
- Requires iOS Notification Service Extension
- Requires custom notification payload with `collapse_id`
- Requires RTDB tracking of read status per device

---

### Story 3.13: Advanced Group Features
**Priority:** P3 (Low)
**Estimated Time:** 2-3 hours

**Features:**
- [ ] Group invite approval (user consent before joining)
- [ ] Restrict who can send messages (admins only mode)
- [ ] Group description field (shown in Group Info)
- [ ] Pinned messages in groups
- [ ] Group search (find groups by name)
- [ ] Group categories/tags
- [ ] Archive/unarchive groups
- [ ] Group member roles (admin, moderator, member)

---

### Story 3.14: Group Media Gallery
**Priority:** P3 (Low)
**Estimated Time:** 90 minutes

**Features:**
- [ ] Shared media tab in Group Info
- [ ] Grid view of all images/videos sent in group
- [ ] Filter by media type (photos, videos, files, links)
- [ ] Download all media option
- [ ] Delete media from conversation (admins only)

---

### Story 3.15: Group Analytics (Admin Only)
**Priority:** P4 (Nice-to-Have)
**Estimated Time:** 45 minutes

**Features:**
- [ ] Message activity graph (messages per day)
- [ ] Most active members chart
- [ ] Peak messaging hours
- [ ] Group growth over time

---

**Total Post-MVP Scope:** 5-7 hours additional work
**Recommended Phase:** After MVP launch, based on user feedback

---

**Epic Status:** MVP Stories 3.10-3.12 require implementation
**Blockers:** None (extends existing infrastructure)
**Risk Level:** Low (incremental changes to working code)

**Last Updated:** 2025-10-22 (Added Stories 3.10-3.12 for MVP completion)
