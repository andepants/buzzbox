# Epic 5: Single-Creator Platform Redesign

**Phase:** Day 2-3 (Critical Architecture Pivot)
**Priority:** P0 (CRITICAL - Enables AI Features Worth 30 Points)
**Estimated Time:** 1.5-2 hours (reduced from 4 hours)
**Epic Owner:** Product Owner
**Dependencies:** Epic 2 (One-on-One Chat), Epic 3 (Group Chat)

---

## 📋 Strategic Context

### Why This Epic Exists

**Current State:** Peer-to-peer messenger where any user can message any user (WhatsApp clone).

**Problem:** The Content Creator/Influencer persona's AI features don't make sense in peer-to-peer architecture:
- Auto-categorization of fan DMs → Requires managing INBOUND communication at scale
- Response drafting in creator's voice → Requires one creator's consistent voice
- FAQ auto-responder → Requires repetitive questions to ONE creator
- Sentiment analysis → Requires analyzing messages TO one creator
- Collaboration opportunity scoring → Requires filtering ONE creator's business DMs

**These features require ONE creator managing their fan inbox, not peer-to-peer chat.**

### The Pivot

Transform from **peer-to-peer messenger** → **single-creator fan engagement platform**.

**Product Model:**
- **ONE creator:** Andrew Heim Dev (hardcoded email: andrewsheim@gmail.com)
- **All other users:** Fans/members who join Andrew's community
- **Channels:** Discord-style topic channels (#general, #announcements, #off-topic)
- **DMs:** Fans can DM Andrew, Andrew can respond (AI-powered inbox)
- **No peer-to-peer:** Fans cannot DM other fans

**Why This Works:**
1. ✅ AI features make PERFECT sense (one creator's inbox management)
2. ✅ MUCH simpler than multi-creator platform (1.5 hours vs 4 hours)
3. ✅ Real product pattern (Discord server, Telegram channel, Patreon chat)
4. ✅ Enables ALL 5 AI features (30 points)
5. ✅ Keeps 90% of existing code (channels = group chats)
6. ✅ Focused demo (Andrew's personal community app)

---

## 🎯 What This Epic Delivers

### User Experience

**For Andrew (The Creator):**
- ✅ Receives DMs from fans (AI-powered inbox - Epic 6)
- ✅ Hosts channels (topic-based group discussions)
- ✅ Moderates channels (delete messages, future: remove users)
- ✅ Posts announcements (creator-only channel)

**For Fans:**
- ✅ Join Andrew's community via email (no verification needed)
- ✅ Chat in public channels with other fans
- ✅ Send DMs to Andrew
- ✅ See Andrew's profile

**What's Gone:**
- ❌ Peer-to-peer messaging (fan-to-fan DMs)
- ❌ User type selection onboarding (everyone except Andrew = fan)
- ❌ Creator discovery (only one creator exists)
- ❌ Multiple communities (only Andrew's community)
- ❌ Phone authentication (email only, no verification)

---

## 📊 High-Level Changes Overview

### 1. Authentication Changes (30 min)

**Remove Phone Auth, Add Email Auth:**
- Firebase Email/Password authentication (no email verification)
- User enters email + password → creates account → immediately logged in
- **Dev mode auto-login:** Button to login as Andrew (andrewsheim@gmail.com / test1234)

**Creator Identification:**
```swift
// Hardcoded creator email
let CREATOR_EMAIL = "andrewsheim@gmail.com"

// After user signs up/in:
if user.email == CREATOR_EMAIL {
    user.userType = .creator
    user.isPublic = true
} else {
    user.userType = .fan
    user.isPublic = false
}
```

**Code Impact:** MEDIUM - Replace phone auth with email auth, add dev login button

---

### 2. User Model Changes (10 min)

**Add User Types:**
- `UserType` enum: `.creator` or `.fan`
- `isPublic` bool: Creator is visible, fans are private
- No onboarding choice needed (auto-assigned based on email)

**Code Impact:** LOW - Add 2 properties, auto-assign based on email

---

### 3. Channel Model (Rebrand Group Chats) (20 min)

**Channels = Topic-Based Group Chats:**
- Rebrand "group chats" as "channels"
- Pre-create default channels on first launch
- Creator can add more channels later (future enhancement)

**Default Channels:**
1. **#general** - Main discussion (everyone can post)
2. **#announcements** - Creator posts only (fans read-only)
3. **#off-topic** - Casual chat (everyone can post)

**Channel Permissions:**
- `#announcements`: Only creator can post
- All other channels: Everyone can post

**Technical:**
- Channels = `ConversationEntity` with `isGroup = true`
- Add `isCreatorOnly: Bool` field for permissions
- Reuses 100% of existing group chat infrastructure

**Code Impact:** LOW - Rename UI elements, add one boolean field, seed default channels

---

### 4. DM Restrictions (15 min)

**Rules:**
- Fans can ONLY DM the creator (Andrew)
- Creator can respond to any fan DM
- Fans CANNOT DM other fans

**Implementation:**
- Check recipient's `userType` before creating DM
- If recipient is `.fan` and sender is `.fan` → block
- UI: Only show "Message Andrew" option (no user search)

**Code Impact:** LOW - Simple permission check in DM creation flow

---

### 5. Navigation Changes (15 min)

**Fan Navigation:**
```
Tab 1: Channels (list of channels)
Tab 2: DMs (their conversation with Andrew)
Tab 3: Profile
```

**Creator Navigation:**
```
Tab 1: Channels (same list, can post anywhere)
Tab 2: Inbox (fan DMs - highlighted, future: AI features)
Tab 3: Profile
Tab 4: Settings (future: manage channels)
```

**Code Impact:** LOW - Conditional tab bar based on `userType`

---

### 6. Simplified Onboarding (10 min)

**New User Flow:**
```
1. Enter email + password
2. Set username + profile photo (optional)
3. → Immediately see channels + welcome message in #general
```

**No user type selection, no verification, no phone number.**

**Code Impact:** LOW - Remove phone auth screens, simplify onboarding

---

## 🔄 What Stays EXACTLY The Same

### Messaging Infrastructure (100% Reuse)
- ✅ Firebase Realtime Database for messages
- ✅ SwiftData offline-first architecture
- ✅ Real-time message delivery
- ✅ Typing indicators
- ✅ Read receipts
- ✅ Push notifications
- ✅ Message persistence
- ✅ Offline queue and sync

### Group Chat Logic (100% Reuse)
- ✅ Multi-user messaging (now called "channels")
- ✅ Message attribution (names, avatars)
- ✅ Group read receipts
- ✅ Member management
- ✅ Group photos

### UI Components (95% Reuse)
- ✅ MessageBubbleView
- ✅ MessageComposerView
- ✅ MessageThreadView
- ✅ ConversationListView (minor rename to "channels")
- ✅ ProfileView

**This is NOT a rewrite. This is a 1.5-2 hour refactor.**

---

## 📝 User Stories

### Story 5.1: Email Authentication (30 min)
**As a new user, I want to create an account with email so I can join Andrew's community.**

**Changes:**
- Remove all phone auth code
- Add Firebase Email/Password authentication
- No email verification (production mode always enabled)
- Email + password form → create account → logged in
- Auto-assign `userType` based on email (andrewsheim@gmail.com = creator)

**Dev Feature:**
- Add "Dev Login" button in login screen
- Tapping it auto-fills andrewsheim@gmail.com / test1234 and logs in
- Hidden in production builds (conditional compilation)

**Estimate:** 30 min

**Acceptance Criteria:**
- User can sign up with email/password
- User can login with email/password
- No email verification required
- Andrew's email automatically gets creator privileges
- Dev login button works in debug builds

---

### Story 5.2: User Type Auto-Assignment (10 min)
**As the system, I want to automatically assign user types so Andrew is the creator and everyone else is a fan.**

**Changes:**
- Add `userType: UserType` and `isPublic: Bool` to `UserEntity`
- On user creation, check email:
  - If email == "andrewsheim@gmail.com" → creator
  - Else → fan
- No UI changes needed (automatic)

**Estimate:** 10 min

**Acceptance Criteria:**
- Andrew's account has `userType = .creator`
- All other accounts have `userType = .fan`
- No onboarding selection screen

---

### Story 5.3: Channel System (20 min)
**As a fan, I want to see topic-based channels so I can participate in organized discussions.**

**Changes:**
- Rename "Groups" to "Channels" in UI
- Seed 3 default channels on app first launch:
  - #general (everyone can post)
  - #announcements (creator only)
  - #off-topic (everyone can post)
- Add `isCreatorOnly: Bool` to `ConversationEntity`
- UI: Show lock icon for creator-only channels

**Estimate:** 20 min

**Acceptance Criteria:**
- First app launch creates 3 default channels
- Channels use existing group chat infrastructure
- #announcements blocks fan posting (shows read-only UI)
- Channel list shows all 3 channels

---

### Story 5.4: DM Restrictions (15 min)
**As the system, I want to restrict DMs so fans can only message Andrew, not each other.**

**Changes:**
- Update DM creation logic to check recipient type
- Block fan-to-fan DM creation
- UI: "Message Andrew" button in profile/menu (no user search)
- Creator can respond to any DM

**Estimate:** 15 min

**Acceptance Criteria:**
- Fans can create DMs with creator only
- Attempting fan-to-fan DM shows error or is blocked
- Creator can reply to all DMs

---

### Story 5.5: Creator Inbox View (15 min)
**As Andrew, I want to see all my fan DMs in one place so I can manage them (and later use AI features).**

**Changes:**
- Add "Inbox" tab for creator (replaces generic "DMs")
- Shows all DMs from fans
- Sorted by most recent
- Badge count for unread DMs
- Fans just see "DMs" tab (their conversation with Andrew)

**Estimate:** 15 min

**Acceptance Criteria:**
- Creator sees "Inbox" tab with all fan conversations
- Fans see "DMs" tab with their Andrew conversation
- Unread badge shows on creator's inbox

---

### Story 5.6: Simplified Navigation (10 min)
**As a user, I want clear navigation so I can easily access channels and DMs.**

**Changes:**
- Update tab bar to be conditional on `userType`:
  - Fans: Channels | DMs | Profile
  - Creator: Channels | Inbox | Profile (| Settings - future)
- Remove "New Group" button (channels are pre-created)
- Add "Message Andrew" button somewhere accessible for fans

**Estimate:** 10 min

**Acceptance Criteria:**
- Fans see 3 tabs
- Creator sees 3-4 tabs
- Navigation is clear and intuitive

---

## 🗄️ Data Model Changes

### UserEntity (Add 2 Properties)
```swift
@Model
final class UserEntity {
    // EXISTING (keep all):
    var id: String
    var email: String              // Changed from phoneNumber
    var displayName: String
    var bio: String?
    var photoURL: String?
    var isOnline: Bool
    var lastSeen: Date?

    // NEW (add these):
    var userType: UserType         // .creator or .fan
    var isPublic: Bool              // Discoverable (creator = true, fans = false)
}

enum UserType: String, Codable {
    case creator
    case fan
}
```

### ConversationEntity (Add 1 Property)
```swift
@Model
final class ConversationEntity {
    // EXISTING (keep all):
    var id: String
    var participantIDs: [String]
    var isGroup: Bool
    var name: String?
    var photoURL: String?
    var createdAt: Date
    var lastMessageAt: Date?

    // NEW (add these):
    var isCreatorOnly: Bool         // For #announcements (creator-only posting)
}
```

---

## 🎨 UI Changes Summary

### Modified Screens
1. **LoginView** - Replace phone auth with email/password, add dev login button (30 min)
2. **OnboardingView** - Simplify (no user type selection, just profile setup) (10 min)
3. **ConversationListView** - Rename to "Channels", filter by channel type (10 min)
4. **TabBarView** - Conditional tabs based on userType (10 min)
5. **ProfileView** - Show creator badge for Andrew (5 min)

### No New Screens Needed
- Reuse existing chat screens
- Reuse existing profile screens
- Reuse existing group chat UI (now "channels")

**Total UI Work:** ~1 hour 5 min

---

## 🔐 Firebase Security Rules Changes

### Realtime Database Rules (15 min)

```javascript
{
  "rules": {
    // Messages: Only conversation participants can access
    "conversations": {
      "$conversationId": {
        "messages": {
          ".read": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists()",
          ".write": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists()",

          "$messageId": {
            // For creator-only channels, only creator can write
            ".write": "auth != null && (
              !root.child('conversations').child($conversationId).child('isCreatorOnly').val() ||
              root.child('users').child(auth.uid).child('userType').val() == 'creator'
            )"
          }
        }
      }
    }
  }
}
```

### Firestore Rules (15 min)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: Creator is readable by all, fans are private
    match /users/{userID} {
      allow read: if request.auth != null && (
        userID == request.auth.uid ||
        resource.data.userType == 'creator'
      );
      allow write: if request.auth.uid == userID;
    }

    // Conversations: Only participants can access
    match /conversations/{conversationID} {
      allow read: if request.auth.uid in resource.data.participantIDs;
      allow create: if request.auth.uid in request.resource.data.participantIDs;

      // Only creator can delete
      allow delete: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userType == 'creator';
    }
  }
}
```

---

## ⏱️ Time Breakdown

| Story | Description | Time |
|-------|-------------|------|
| 5.1 | Email Authentication + Dev Login | 30 min |
| 5.2 | User Type Auto-Assignment | 10 min |
| 5.3 | Channel System (rename groups) | 20 min |
| 5.4 | DM Restrictions | 15 min |
| 5.5 | Creator Inbox View | 15 min |
| 5.6 | Simplified Navigation | 10 min |
| **TOTAL** | | **1 hour 40 min** |

### Add 20 min buffer for Firebase rules = **2 hours total**

---

## ✅ Success Criteria

**Epic 5 is complete when:**

### Functional Requirements
- ✅ Users can sign up/login with email (no verification)
- ✅ Andrew's account is automatically creator type
- ✅ All other accounts are automatically fan type
- ✅ Default channels exist (#general, #announcements, #off-topic)
- ✅ Fans can only post in non-creator-only channels
- ✅ Fans can only DM Andrew (not other fans)
- ✅ Creator sees "Inbox" tab, fans see "DMs" tab
- ✅ Dev login button works

### Technical Requirements
- ✅ UserEntity has `userType` and `isPublic` fields
- ✅ ConversationEntity has `isCreatorOnly` field
- ✅ Phone auth code completely removed
- ✅ All existing messaging infrastructure still works
- ✅ No regressions in real-time sync, offline support, or read receipts
- ✅ Firebase rules enforce creator/fan permissions

### UX Requirements
- ✅ Channels feel like Discord (topic-based discussion)
- ✅ Creator inbox feels purpose-built for managing DMs
- ✅ Fan experience is simple (join → chat in channels → DM Andrew)
- ✅ Onboarding is fast (email → username → start chatting)

---

## 🚨 Risks & Mitigations

### Risk 1: Breaking Existing Messaging
**Mitigation:** Make changes additive, not destructive
- Add new fields, don't modify existing ones
- Channels = existing group chats with new flag
- Test DMs and channels after each change

### Risk 2: Email Auth Security
**Mitigation:** Use Firebase best practices
- Password requirements enforced by Firebase
- Dev login only in debug builds
- Production always uses secure Firebase auth

### Risk 3: Scope Creep
**Mitigation:** Ship minimal viable version
- Phase 1: Basic creator/fan model (1.5 hrs)
- Phase 2: Advanced moderation (defer to post-Epic 6)
- Phase 3: Creator channel management (defer)

---

## 🎯 Why This Enables 30 AI Points

### Points Breakdown After Epic 5

| Section | Points | Status After Epic 5 |
|---------|--------|---------------------|
| **1. Core Messaging** | 35 pts | ✅ 28-30 pts (unchanged) |
| **2. Mobile Quality** | 20 pts | ✅ 15-17 pts (unchanged) |
| **3. AI Features** | 30 pts | 🟢 **NOW POSSIBLE** (Epic 6) |
| **4. Technical** | 10 pts | ✅ 7-8 pts (unchanged) |
| **5. Docs/Deploy** | 5 pts | ✅ 3-4 pts (minor updates) |

**Epic 5 unlocks the 30 AI points by creating the right architecture.**

With Single-Creator Model:
- ✅ All 5 AI features make perfect sense
- ✅ One creator voice for response drafting
- ✅ One creator's FAQs for auto-responder
- ✅ One creator's inbox for categorization
- ✅ Focused demo showing AI managing Andrew's fan communication
- ✅ **Total: 80-85 points (B)**

---

## 📦 Implementation Order

### Phase 1: Auth Changes (40 min)
1. Remove phone auth code
2. Add email/password auth
3. Add dev login button
4. Add user type auto-assignment

### Phase 2: Channel System (20 min)
5. Rename groups to channels
6. Seed default channels
7. Add creator-only flag

### Phase 3: DM & Navigation (30 min)
8. Add DM restrictions
9. Add creator inbox view
10. Update tab bar navigation

### Phase 4: Testing & Rules (30 min)
11. Test all flows (signup, channels, DMs)
12. Update Firebase security rules
13. Verify creator/fan permissions

**Total: 2 hours**

---

## 📚 References

- **Project Brief:** `docs/project-brief.md` (Content Creator persona)
- **Scoring Rubric:** `docs/scoring.md` (AI Features = 30 pts)
- **Epic 2:** One-on-One Chat (messaging infrastructure)
- **Epic 3:** Group Chat (channel foundation)

---

## 🎬 Next Steps

**After Epic 5 Completion:**
1. ✅ Single-creator model is live
2. ✅ Channels are working (#general, #announcements, #off-topic)
3. ✅ Andrew has an inbox for fan DMs
4. 🚀 **Epic 6: Implement ALL 5 AI Features** (6-8 hrs, worth 30 points)

**Priority Order:**
1. Epic 5 (this) - 2 hours → Enables AI
2. Epic 6 (AI features) - 6-8 hours → 30 points
3. Epic 7 (Polish & deliverables) - 2-3 hours → Avoid penalties
4. Epic 4 (Media sharing) - **SKIP** → Only 2-3 points, not critical

---

**Epic Status:** 🟢 Ready to Implement
**Blockers:** None
**Risk Level:** Low (simplified architecture, additive changes)
**Strategic Value:** CRITICAL - Unlocks 30 AI points with minimal effort

**Recommendation: START EPIC 5 NOW. This is the foundation for everything.**
