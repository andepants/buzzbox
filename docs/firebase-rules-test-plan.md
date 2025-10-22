# Firebase RTDB Rules Test Plan

**Purpose:** Validate that the updated Firebase Realtime Database rules correctly enforce group chat security and constraints.

**Date:** 2025-10-21
**Epic:** Epic 3 - Group Chat
**Rules Version:** Post-fixes (admin permissions, participant limits, system messages)

---

## Test Environment Setup

### Prerequisites:
1. ✅ Firebase rules deployed to project `sorted-d3844-default-rtdb`
2. ✅ Firebase Authentication enabled with test users
3. ✅ Firebase Console access for manual testing

### Test Users:
- **User A (alice):** `UID: test-user-alice`, will be group admin
- **User B (bob):** `UID: test-user-bob`, regular participant
- **User C (charlie):** `UID: test-user-charlie`, regular participant
- **User D (diana):** `UID: test-user-diana`, non-participant

---

## Test Categories

### 1. ✅ Group Creation Tests

#### Test 1.1: Valid Group Creation (Should PASS)
**Actor:** User A (authenticated)
**Action:** Create group with User A, User B, User C as participants
**Expected Result:** ✅ SUCCESS

**RTDB Write:**
```json
// Path: /conversations/group_001/
{
  "participants": {
    "test-user-alice": true,
    "test-user-bob": true,
    "test-user-charlie": true
  },
  "participantList": ["test-user-alice", "test-user-bob", "test-user-charlie"],
  "isGroup": true,
  "groupName": "Test Group",
  "groupPhotoURL": "https://storage.googleapis.com/group_photos/group_001/group_photo.jpg",
  "adminUserIDs": {
    "test-user-alice": true
  },
  "createdAt": 1729512000000,
  "updatedAt": 1729512000000,
  "lastMessage": "",
  "lastMessageTimestamp": 1729512000000
}
```

**Validation:**
- ✅ User A is in participants
- ✅ isGroup = true
- ✅ groupName is 1-50 characters
- ✅ participantList.length = 3 (min 2, max 256)
- ✅ adminUserIDs contains User A

---

#### Test 1.2: Group Creation with 1 Participant (Should FAIL)
**Actor:** User A (authenticated)
**Action:** Create group with only User A
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Write:**
```json
{
  "participants": { "test-user-alice": true },
  "participantList": ["test-user-alice"],
  "isGroup": true,
  "groupName": "Solo Group"
}
```

**Validation:**
- ❌ participantList.length = 1 (violates min 2 rule)
- **Expected Error:** `".validate": "newData.val().length >= 2"`

---

#### Test 1.3: Group Creation with 300 Participants (Should FAIL)
**Actor:** User A (authenticated)
**Action:** Create group with 300 participants
**Expected Result:** ❌ PERMISSION_DENIED

**Validation:**
- ❌ participantList.length = 300 (violates max 256 rule)
- **Expected Error:** `".validate": "newData.val().length <= 256"`

---

#### Test 1.4: Group Creation with Invalid Name (Should FAIL)
**Actor:** User A (authenticated)
**Action:** Create group with 51-character name
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Write:**
```json
{
  "groupName": "This is a very long group name that exceeds the fifty character limit"
}
```

**Validation:**
- ❌ groupName.length = 51 (violates max 50 rule)
- **Expected Error:** `".validate": "newData.val().length <= 50"`

---

### 2. ✅ Admin Permission Tests

#### Test 2.1: Admin Modifies Group Name (Should PASS)
**Actor:** User A (admin)
**Action:** Update group name from "Test Group" to "Updated Group"
**Expected Result:** ✅ SUCCESS

**RTDB Update:**
```json
// Path: /conversations/group_001/
{
  "groupName": "Updated Group",
  "updatedAt": 1729512100000
}
```

**Validation:**
- ✅ User A is in adminUserIDs
- ✅ New groupName is 1-50 characters

---

#### Test 2.2: Non-Admin Tries to Modify Group Name (Should FAIL)
**Actor:** User B (participant, NOT admin)
**Action:** Update group name
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Update:**
```json
// Path: /conversations/group_001/
{
  "groupName": "Hacked Group Name"
}
```

**Validation:**
- ❌ User B is NOT in adminUserIDs
- **Expected Error:** Write rule checks `data.child('adminUserIDs').child(auth.uid).val() == true`

---

#### Test 2.3: Admin Adds Participant (Should PASS)
**Actor:** User A (admin)
**Action:** Add User D to group
**Expected Result:** ✅ SUCCESS

**RTDB Update:**
```json
// Path: /conversations/group_001/
{
  "participants": {
    "test-user-alice": true,
    "test-user-bob": true,
    "test-user-charlie": true,
    "test-user-diana": true
  },
  "participantList": ["test-user-alice", "test-user-bob", "test-user-charlie", "test-user-diana"],
  "updatedAt": 1729512200000
}
```

**Validation:**
- ✅ User A is admin
- ✅ participantList.length = 4 (within 2-256 range)

---

#### Test 2.4: Non-Admin Tries to Add Participant (Should FAIL)
**Actor:** User B (participant, NOT admin)
**Action:** Add User D to group
**Expected Result:** ❌ PERMISSION_DENIED

**Validation:**
- ❌ User B is NOT in adminUserIDs
- **Expected Error:** Admin check fails

---

#### Test 2.5: Admin Removes Participant (Should PASS)
**Actor:** User A (admin)
**Action:** Remove User C from group
**Expected Result:** ✅ SUCCESS

**RTDB Update:**
```json
{
  "participants": {
    "test-user-alice": true,
    "test-user-bob": true
  },
  "participantList": ["test-user-alice", "test-user-bob"],
  "updatedAt": 1729512300000
}
```

**Validation:**
- ✅ User A is admin
- ✅ participantList.length = 2 (min met)

---

### 3. ✅ System Message Tests

#### Test 3.1: Valid System Message (Should PASS)
**Actor:** User A (admin, via app logic)
**Action:** Send system message "Alice created the group"
**Expected Result:** ✅ SUCCESS

**RTDB Write:**
```json
// Path: /messages/group_001/msg_001/
{
  "senderID": "system",
  "text": "Alice created the group",
  "serverTimestamp": 1729512400000,
  "status": "sent",
  "isSystemMessage": true
}
```

**Validation:**
- ✅ isSystemMessage = true
- ✅ senderID = "system"
- **Rule:** `(newData.parent().child('isSystemMessage').val() == true && newData.val() == 'system')`

---

#### Test 3.2: System Message with Wrong SenderID (Should FAIL)
**Actor:** User A (attempting to forge system message)
**Action:** Send system message with senderID = "test-user-alice"
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Write:**
```json
{
  "senderID": "test-user-alice",
  "text": "Fake system message",
  "isSystemMessage": true
}
```

**Validation:**
- ❌ isSystemMessage = true but senderID != "system"
- **Expected Error:** senderID validation fails

---

#### Test 3.3: Regular Message from User (Should PASS)
**Actor:** User B (participant)
**Action:** Send regular message
**Expected Result:** ✅ SUCCESS

**RTDB Write:**
```json
// Path: /messages/group_001/msg_002/
{
  "senderID": "test-user-bob",
  "text": "Hello everyone!",
  "serverTimestamp": 1729512500000,
  "status": "sent",
  "isSystemMessage": false
}
```

**Validation:**
- ✅ isSystemMessage = false (or not present)
- ✅ senderID = auth.uid (test-user-bob)

---

#### Test 3.4: User Tries to Impersonate Another User (Should FAIL)
**Actor:** User B (authenticated)
**Action:** Send message with senderID = "test-user-alice"
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Write:**
```json
{
  "senderID": "test-user-alice",
  "text": "Impersonation attempt",
  "isSystemMessage": false
}
```

**Validation:**
- ❌ senderID != auth.uid
- **Expected Error:** `".validate": "newData.val() == auth.uid"`

---

### 4. ✅ Read Receipts Tests

#### Test 4.1: User Marks Message as Read (Should PASS)
**Actor:** User B (participant)
**Action:** Mark message as read
**Expected Result:** ✅ SUCCESS

**RTDB Update:**
```json
// Path: /messages/group_001/msg_002/readBy/
{
  "test-user-bob": 1729512600000
}
```

**Validation:**
- ✅ readBy is dictionary of userID -> timestamp (number)
- **Rule:** `"$uid": { ".validate": "newData.isNumber()" }`

---

#### Test 4.2: Invalid Read Receipt (Should FAIL)
**Actor:** User B (participant)
**Action:** Write non-numeric timestamp
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Update:**
```json
{
  "test-user-bob": "invalid-timestamp"
}
```

**Validation:**
- ❌ Value is string, not number
- **Expected Error:** `".validate": "newData.isNumber()"`

---

### 5. ✅ Participant Access Tests

#### Test 5.1: Participant Reads Group Messages (Should PASS)
**Actor:** User B (participant)
**Action:** Read messages in group_001
**Expected Result:** ✅ SUCCESS

**RTDB Read:**
```json
// Path: /messages/group_001/
```

**Validation:**
- ✅ User B is in participants
- **Rule:** `".read": "root.child('conversations').child($conversationID).child('participants').child(auth.uid).val() == true"`

---

#### Test 5.2: Non-Participant Tries to Read Messages (Should FAIL)
**Actor:** User D (NOT a participant)
**Action:** Read messages in group_001
**Expected Result:** ❌ PERMISSION_DENIED

**Validation:**
- ❌ User D is NOT in participants
- **Expected Error:** Read rule checks participant status

---

#### Test 5.3: Participant Updates Last Message (Should PASS)
**Actor:** User C (participant)
**Action:** Update lastMessage in conversation
**Expected Result:** ✅ SUCCESS

**RTDB Update:**
```json
// Path: /conversations/group_001/
{
  "lastMessage": "Latest message preview",
  "lastMessageTimestamp": 1729512700000,
  "updatedAt": 1729512700000
}
```

**Validation:**
- ✅ User C is participant
- ✅ NOT modifying admin-only fields (groupName, groupPhotoURL, participantList)

---

### 6. ✅ Edge Cases

#### Test 6.1: Empty Group Name (Should FAIL)
**Actor:** User A (admin)
**Action:** Set groupName to empty string
**Expected Result:** ❌ PERMISSION_DENIED

**RTDB Update:**
```json
{
  "groupName": ""
}
```

**Validation:**
- ❌ groupName.length = 0 (violates min 1 rule)
- **Expected Error:** `".validate": "newData.val().length >= 1"`

---

#### Test 6.2: Group with Exactly 2 Participants (Should PASS)
**Actor:** User A (admin)
**Action:** Create minimal group (2 participants)
**Expected Result:** ✅ SUCCESS

**RTDB Write:**
```json
{
  "participantList": ["test-user-alice", "test-user-bob"]
}
```

**Validation:**
- ✅ participantList.length = 2 (meets minimum)

---

#### Test 6.3: Group with Exactly 256 Participants (Should PASS)
**Actor:** User A (admin)
**Action:** Create maximum group (256 participants)
**Expected Result:** ✅ SUCCESS

**Validation:**
- ✅ participantList.length = 256 (meets maximum)

---

## Automated Test Script (Swift)

**Location:** Create file at `sorted/Tests/FirebaseRulesTests.swift`

```swift
import XCTest
@testable import sorted
import FirebaseDatabase
import FirebaseAuth

final class FirebaseRulesTests: XCTestCase {

    var database: DatabaseReference!

    override func setUp() async throws {
        database = Database.database().reference()

        // Sign in as test user A (admin)
        try await Auth.auth().signIn(withEmail: "alice@test.com", password: "testpassword123")
    }

    // MARK: - Group Creation Tests

    func testValidGroupCreation() async throws {
        let conversationRef = database.child("conversations/group_test_001")

        let conversationData: [String: Any] = [
            "participants": [
                "test-user-alice": true,
                "test-user-bob": true,
                "test-user-charlie": true
            ],
            "participantList": ["test-user-alice", "test-user-bob", "test-user-charlie"],
            "isGroup": true,
            "groupName": "Test Group",
            "adminUserIDs": ["test-user-alice": true],
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970,
            "lastMessage": "",
            "lastMessageTimestamp": Date().timeIntervalSince1970
        ]

        // Should succeed
        try await conversationRef.setValue(conversationData)

        // Verify data was written
        let snapshot = try await conversationRef.getData()
        XCTAssertTrue(snapshot.exists())
    }

    func testGroupCreationWithOneParticipant() async throws {
        let conversationRef = database.child("conversations/group_test_002")

        let conversationData: [String: Any] = [
            "participants": ["test-user-alice": true],
            "participantList": ["test-user-alice"],
            "isGroup": true,
            "groupName": "Solo Group",
            "createdAt": Date().timeIntervalSince1970
        ]

        // Should fail - min 2 participants required
        do {
            try await conversationRef.setValue(conversationData)
            XCTFail("Should have thrown permission denied error")
        } catch {
            // Expected to fail
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
    }

    func testGroupCreationWithInvalidName() async throws {
        let conversationRef = database.child("conversations/group_test_003")

        let longName = String(repeating: "a", count: 51) // 51 characters

        let conversationData: [String: Any] = [
            "participants": [
                "test-user-alice": true,
                "test-user-bob": true
            ],
            "participantList": ["test-user-alice", "test-user-bob"],
            "isGroup": true,
            "groupName": longName,
            "createdAt": Date().timeIntervalSince1970
        ]

        // Should fail - max 50 characters
        do {
            try await conversationRef.setValue(conversationData)
            XCTFail("Should have thrown validation error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
    }

    // MARK: - Admin Permission Tests

    func testAdminCanModifyGroupName() async throws {
        // First create the group
        let conversationRef = database.child("conversations/group_test_004")

        var conversationData: [String: Any] = [
            "participants": [
                "test-user-alice": true,
                "test-user-bob": true
            ],
            "participantList": ["test-user-alice", "test-user-bob"],
            "isGroup": true,
            "groupName": "Original Name",
            "adminUserIDs": ["test-user-alice": true],
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970,
            "lastMessage": "",
            "lastMessageTimestamp": Date().timeIntervalSince1970
        ]

        try await conversationRef.setValue(conversationData)

        // Now update as admin
        conversationData["groupName"] = "Updated Name"
        try await conversationRef.setValue(conversationData)

        // Verify update
        let snapshot = try await conversationRef.child("groupName").getData()
        XCTAssertEqual(snapshot.value as? String, "Updated Name")
    }

    // MARK: - System Message Tests

    func testValidSystemMessage() async throws {
        let messageRef = database.child("messages/group_test_001/msg_system_001")

        let messageData: [String: Any] = [
            "senderID": "system",
            "text": "Alice created the group",
            "serverTimestamp": Date().timeIntervalSince1970,
            "status": "sent",
            "isSystemMessage": true
        ]

        // Should succeed
        try await messageRef.setValue(messageData)

        let snapshot = try await messageRef.getData()
        XCTAssertTrue(snapshot.exists())
    }

    func testSystemMessageWithWrongSender() async throws {
        let messageRef = database.child("messages/group_test_001/msg_system_002")

        let messageData: [String: Any] = [
            "senderID": "test-user-alice", // Wrong! Should be "system"
            "text": "Fake system message",
            "serverTimestamp": Date().timeIntervalSince1970,
            "status": "sent",
            "isSystemMessage": true
        ]

        // Should fail
        do {
            try await messageRef.setValue(messageData)
            XCTFail("Should have thrown validation error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
    }

    // MARK: - Read Receipts Tests

    func testValidReadReceipt() async throws {
        let readByRef = database.child("messages/group_test_001/msg_001/readBy/test-user-bob")

        let timestamp = Date().timeIntervalSince1970 * 1000 // Milliseconds

        // Should succeed
        try await readByRef.setValue(timestamp)

        let snapshot = try await readByRef.getData()
        XCTAssertTrue(snapshot.exists())
    }

    func testInvalidReadReceipt() async throws {
        let readByRef = database.child("messages/group_test_001/msg_001/readBy/test-user-bob")

        // Should fail - must be number, not string
        do {
            try await readByRef.setValue("invalid-timestamp")
            XCTFail("Should have thrown validation error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
    }
}
```

---

## Manual Testing Checklist

### Using Firebase Console:

1. ✅ **Navigate to:** https://console.firebase.google.com/project/sorted-d3844/database/sorted-d3844-default-rtdb/data

2. ✅ **Test Group Creation:**
   - Create test conversation with valid data
   - Try creating with 1 participant (should fail)
   - Try 51-character group name (should fail)

3. ✅ **Test Admin Permissions:**
   - Sign in as admin user → modify group name (should succeed)
   - Sign in as non-admin → modify group name (should fail)

4. ✅ **Test System Messages:**
   - Create message with `isSystemMessage: true` and `senderID: "system"` (should succeed)
   - Create message with `isSystemMessage: true` and `senderID: "user-123"` (should fail)

5. ✅ **Test Read Receipts:**
   - Add read receipt with numeric timestamp (should succeed)
   - Add read receipt with string timestamp (should fail)

---

## Expected Results Summary

| Test Category | Total Tests | Expected PASS | Expected FAIL |
|---------------|-------------|---------------|---------------|
| Group Creation | 4 | 1 | 3 |
| Admin Permissions | 5 | 3 | 2 |
| System Messages | 4 | 2 | 2 |
| Read Receipts | 2 | 1 | 1 |
| Participant Access | 3 | 2 | 1 |
| Edge Cases | 3 | 2 | 1 |
| **TOTAL** | **21** | **11** | **10** |

---

## How to Run Tests

### Option 1: Firebase Console (Manual)
1. Go to: https://console.firebase.google.com/project/sorted-d3844/database
2. Use the "Rules Playground" to test read/write operations
3. Manually verify each test case above

### Option 2: Swift Unit Tests (Automated)
1. Add `FirebaseRulesTests.swift` to your Xcode project
2. Configure test users in Firebase Auth
3. Run: `⌘ + U` in Xcode

### Option 3: Firebase Emulator Suite (Recommended for CI/CD)
```bash
# Install Firebase Emulator
npm install -g firebase-tools

# Start emulator with auth and database
firebase emulators:start --only auth,database

# Run tests against emulator
# (Update database reference in tests to use emulator URL)
```

---

## Sign-off

**Rules Deployed:** ✅ 2025-10-21
**Test Plan Created:** ✅ 2025-10-21
**Ready for Epic 3:** ✅ YES

**Next Steps:** Begin Story 3.1 (Create Group Conversation) implementation.
