# Story 5.7: Firebase Security Rules Deployment

## Status
Draft

## Story
**As a** developer,
**I want** to deploy updated Firebase security rules,
**so that** creator/fan permissions are enforced server-side and data is secure.

## Acceptance Criteria

1. Firestore security rules enforce userType-based access control
2. Realtime Database rules enforce channel posting permissions
3. Creator profile is publicly readable (isPublic = true)
4. Fans can read other fan profiles (for channel participant context)
5. Only the creator or conversation participants can write to conversations
6. DM creation is restricted: both participants cannot be fans
7. Creator-only channels (isCreatorOnly = true) only allow creator to post
8. Rules tested in Firebase console simulator before deployment
9. Rules deployed to production Firebase project
10. Rollback procedure documented
11. All existing functionality verified after deployment

## Tasks / Subtasks

- [ ] Update Firestore security rules (AC: 1, 3, 4, 5, 6)
  - [ ] Add userType-based user profile access rules
  - [ ] Allow creator profile to be read by all authenticated users
  - [ ] Allow fans to read any user profile (for channel context)
  - [ ] Enforce DM restriction: reject if both participants are fans
  - [ ] Only allow users to update their own profile
  - [ ] Only conversation participants can read/write conversations
  - [ ] Test rules in Firestore console simulator

- [ ] Update Realtime Database security rules (AC: 2, 7)
  - [ ] Enforce conversation participant read/write permissions
  - [ ] Add isCreatorOnly channel permission check
  - [ ] Only creator can write to isCreatorOnly channels
  - [ ] Everyone can write to non-creator-only channels
  - [ ] Test rules in RTDB console simulator

- [ ] Test rules in Firebase console (AC: 8)
  - [ ] Use Rules Playground to simulate fan-to-fan DM creation (should fail)
  - [ ] Simulate fan posting to #announcements (should fail)
  - [ ] Simulate fan posting to #general (should succeed)
  - [ ] Simulate creator posting to #announcements (should succeed)
  - [ ] Verify all test cases pass before deployment

- [ ] Deploy rules to production (AC: 9)
  - [ ] Back up current rules (export from Firebase console)
  - [ ] Deploy Firestore rules via Firebase CLI or console
  - [ ] Deploy Realtime Database rules via Firebase CLI or console
  - [ ] Verify deployment success
  - [ ] Check Firebase console for deployment errors

- [ ] Document rollback procedure (AC: 10)
  - [ ] Save previous rules version to version control
  - [ ] Document steps to restore previous rules
  - [ ] Test rollback procedure in development environment
  - [ ] Create rollback script if needed

- [ ] Verify all features post-deployment (AC: 11)
  - [ ] Test fan signup and channel auto-join
  - [ ] Test fan can view Andrew's profile
  - [ ] Test fan can view other fan profiles
  - [ ] Test fan can DM Andrew
  - [ ] Test fan cannot DM another fan (blocked by rules)
  - [ ] Test fan can post to #general
  - [ ] Test fan cannot post to #announcements (blocked by rules)
  - [ ] Test creator can post to all channels
  - [ ] Test creator can DM any fan
  - [ ] Test real-time message delivery still works

## Dev Notes

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function: Check if user is creator
    function isCreator() {
      return request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userType == 'creator';
    }

    // Helper function: Check if user exists
    function userExists(userId) {
      return exists(/databases/$(database)/documents/users/$(userId));
    }

    // Helper function: Get user data
    function getUserData(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data;
    }

    // Users collection
    match /users/{userId} {
      // Creator profile is public (isPublic = true)
      // Fans can read any profile (for channel participant info)
      allow read: if request.auth != null;

      // Only owner can update their own profile
      allow update: if request.auth.uid == userId;

      // User creation during signup
      allow create: if request.auth.uid == userId &&
        request.resource.data.userType in ['creator', 'fan'] &&
        request.resource.data.id == userId;

      // No deletion allowed
      allow delete: if false;
    }

    // Conversations collection
    match /conversations/{conversationId} {
      // Only participants can read conversation
      allow read: if request.auth != null &&
        request.auth.uid in resource.data.participantIDs;

      // Create conversation with validation
      allow create: if request.auth != null &&
        request.auth.uid in request.resource.data.participantIDs &&
        (
          // Group chats/channels: allow creation
          request.resource.data.isGroup == true ||
          // DMs: ensure at least one participant is creator
          (request.resource.data.isGroup == false &&
           request.resource.data.participantIDs.size() == 2 &&
           (getUserData(request.resource.data.participantIDs[0]).userType == 'creator' ||
            getUserData(request.resource.data.participantIDs[1]).userType == 'creator'))
        );

      // Update conversation (adding participants, etc)
      allow update: if request.auth != null &&
        request.auth.uid in resource.data.participantIDs;

      // Only creator can delete conversations
      allow delete: if isCreator();
    }
  }
}
```

### Realtime Database Security Rules

```javascript
{
  "rules": {
    // Conversations and messages
    "conversations": {
      "$conversationId": {
        // Participants metadata
        "participants": {
          ".read": "auth != null && data.child(auth.uid).exists()",
          ".write": "auth != null && data.child(auth.uid).exists()"
        },

        // Messages in conversation
        "messages": {
          // Only participants can read messages
          ".read": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists()",

          // Message write rules
          "$messageId": {
            ".write": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists() && (!root.child('conversations').child($conversationId).child('isCreatorOnly').val() || root.child('users').child(auth.uid).child('userType').val() == 'creator')"
          }
        },

        // Typing indicators
        "typing": {
          ".read": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists()",
          ".write": "auth != null && root.child('conversations').child($conversationId).child('participants').child(auth.uid).exists()"
        }
      }
    },

    // User presence
    "users": {
      "$userId": {
        "presence": {
          ".read": "auth != null",
          ".write": "auth != null && auth.uid == $userId"
        }
      }
    }
  }
}
```

### Deployment Steps

**Using Firebase CLI (Recommended):**
```bash
# 1. Backup current rules
firebase firestore:rules:get > firestore.rules.backup
firebase database:rules:get > database.rules.backup

# 2. Deploy new rules
firebase deploy --only firestore:rules
firebase deploy --only database

# 3. Verify deployment
firebase firestore:rules:get
firebase database:rules:get
```

**Using Firebase Console:**
1. Navigate to Firestore → Rules
2. Copy and paste new Firestore rules
3. Click "Publish"
4. Navigate to Realtime Database → Rules
5. Copy and paste new RTDB rules
6. Click "Publish"

### Rollback Procedure

**If rules cause issues:**
```bash
# Restore from backup
firebase deploy --only firestore:rules --file=firestore.rules.backup
firebase deploy --only database --file=database.rules.backup
```

**Manual rollback via console:**
1. Open Firebase Console
2. Navigate to Firestore → Rules → History
3. Click on previous version
4. Click "Restore"
5. Repeat for Realtime Database

### Rule Testing Scenarios

**Test in Firebase Console Rules Playground:**

1. **Fan-to-Fan DM Creation (Should FAIL):**
   - Simulate: Fan user creating conversation with another fan
   - Expected: Permission denied

2. **Fan-to-Creator DM (Should SUCCEED):**
   - Simulate: Fan user creating conversation with creator
   - Expected: Permission granted

3. **Fan Posting to #general (Should SUCCEED):**
   - Simulate: Fan writing message to general channel
   - Expected: Permission granted

4. **Fan Posting to #announcements (Should FAIL):**
   - Simulate: Fan writing message to announcements (isCreatorOnly=true)
   - Expected: Permission denied

5. **Creator Posting to #announcements (Should SUCCEED):**
   - Simulate: Creator writing message to announcements
   - Expected: Permission granted

### Integration Points
- **Depends on:** All Stories 5.1-5.6 - Rules enforce features from all stories
- **Blocks:** Production deployment - Cannot deploy without proper security rules

### Dependencies
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project access (logged in via `firebase login`)
- Proper permissions to deploy rules (Editor or Owner role)

## Testing

### Testing Standards
- Test all rules in Firebase console simulator before deployment
- Verify each permission scenario passes/fails as expected
- Test on physical device after deployment
- Monitor Firebase console for rule violation errors

### Test Cases

1. **Firestore Rules - User Profiles:**
   - Fan can read creator profile ✅
   - Fan can read other fan profile ✅
   - Fan can update own profile ✅
   - Fan cannot update other profiles ❌
   - Creator profile isPublic = true ✅

2. **Firestore Rules - DM Creation:**
   - Fan can create DM with creator ✅
   - Fan cannot create DM with fan ❌ (blocked by rules)
   - Creator can create DM with any fan ✅
   - Verify error message shown to user

3. **RTDB Rules - Channel Posting:**
   - Fan can post to #general ✅
   - Fan cannot post to #announcements ❌ (blocked by rules)
   - Creator can post to all channels ✅
   - Verify error handling in app

4. **RTDB Rules - Message Reading:**
   - Participants can read conversation messages ✅
   - Non-participants cannot read messages ❌
   - Typing indicators work for participants ✅

5. **Deployment Verification:**
   - Rules deployed successfully
   - No errors in Firebase console
   - Firebase CLI shows latest version
   - Backup files created

6. **Post-Deployment Functionality:**
   - All Epic 5 features still work
   - No regressions in existing features
   - Error messages are user-friendly
   - Real-time sync still works

7. **Rollback Test:**
   - Trigger rollback procedure
   - Verify previous rules restored
   - Verify app functionality after rollback
   - Document rollback success

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial story creation for Epic 5 | Sarah (PO) |

## Dev Agent Record

### Agent Model Used
_To be filled by dev agent_

### Debug Log References
_To be filled by dev agent_

### Completion Notes List
_To be filled by dev agent_

### File List
_To be filled by dev agent_

## QA Results
_To be filled by QA agent_
