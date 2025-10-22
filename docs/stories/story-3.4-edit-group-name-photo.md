---
# Story 3.4: Edit Group Name and Photo
# Epic 3: Group Chat
# Status: Draft

id: STORY-3.4
title: "Edit Group Name and Photo (Admin Only)"
epic: "Epic 3: Group Chat"
status: draft
priority: P1
estimate: 2  # Story points (35 minutes)
assigned_to: null
created_date: "2025-10-21"
sprint_day: null

---

## Description

**As a** group admin
**I need** to edit the group name and photo
**So that** I can keep group information up to date and relevant

This story implements group info editing functionality:
- Change group name (1-50 characters)
- Upload new group photo via ImagePicker
- Admin-only permission enforcement
- Real-time sync to all group members
- System messages for name changes
- Photo upload progress and error handling

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Only group admins can edit group info
- [ ] "Edit Group Info" button opens edit sheet in GroupInfoView
- [ ] User can change group name (1-50 characters validation)
- [ ] User can upload new group photo via ImagePicker
- [ ] Changes save locally (SwiftData) and sync to RTDB
- [ ] All group members see updated info in real-time
- [ ] System message posted: "Alice changed the group name to..."
- [ ] Concurrent edit conflict detection: show toast if another admin changed name
- [ ] Group photo upload shows progress bar (0-100%) with cancel option
- [ ] Large photos (>5MB) compressed before upload
- [ ] Upload failure shows specific error (network, quota, etc.) with retry button

---

## Technical Tasks

**Implementation steps:**

1. **Create EditGroupInfoView** [Source: epic-3-group-chat.md lines 961-1102]
   - Create file: `sorted/Features/Chat/Views/EditGroupInfoView.swift`
   - Form with group photo and name text field
   - Display current group photo (AsyncImage) or new selected photo
   - TextField for group name with character count (max 50)
   - "Save" button (disabled if invalid)
   - "Cancel" button
   - Present as sheet from GroupInfoView

2. **Implement Photo Selection** [Source: epic-3-COMPONENT-SPECS.md]
   - Tap photo button → present ImagePicker sheet
   - Display selected UIImage in preview
   - If no new photo selected, show current `groupPhotoURL`
   - Use ImagePicker component (created in Story 3.1)

3. **Implement Save Logic** [Source: epic-3-group-chat.md lines 1048-1100]
   - Validate group name: non-empty, 1-50 characters
   - Update `conversation.displayName` in SwiftData
   - If photo changed: upload to Storage
   - Show upload progress bar (0-100%)
   - Update `conversation.groupPhotoURL` after upload
   - Set `conversation.syncStatus = .pending`
   - Sync to RTDB via ConversationService
   - Send system message if name changed

4. **Implement Photo Upload with Progress** [Source: epic-3-group-chat.md lines 1058-1069]
   - Use `StorageService.uploadGroupPhoto()` (created in Story 3.1)
   - Show progress bar with percentage
   - Allow upload cancellation
   - Compress large photos (>5MB) to max 5MB
   - Handle upload errors: network, quota, permissions

5. **System Message for Name Change** [Source: epic-3-group-chat.md lines 1078-1096]
   - Only send if name actually changed (compare old vs new)
   - Message text: "{Admin} changed the group name to "{NewName}""
   - `senderID: "system"`, `isSystemMessage: true`
   - Send via MessageService to RTDB

6. **Concurrent Edit Conflict Detection**
   - Before saving, check if `groupName` differs from local value
   - If another admin changed it → show toast: "Group name was updated by another admin"
   - Option to overwrite or cancel

7. **Update GroupInfoView Integration** [Source: epic-3-group-chat.md lines 593-598, 660-662]
   - "Edit Group Info" button visible only to admins
   - Present EditGroupInfoView sheet
   - Reload group info after save

---

## Technical Specifications

### Files to Create

```
sorted/Features/Chat/Views/EditGroupInfoView.swift (create)
```

### Files to Modify

```
sorted/Features/Chat/Views/GroupInfoView.swift (modify - add Edit button)
sorted/Core/Services/StorageService.swift (modify - add progress callback)
sorted/Core/Services/ConversationService.swift (modify - detect concurrent edits)
```

### Data Flow

**Edit Group Info:**
```
1. Admin taps "Edit Group Info" in GroupInfoView
2. EditGroupInfoView sheet appears with current values
3. Admin changes name and/or photo
4. Admin taps "Save"
5. Validate name (1-50 chars, non-empty)
6. If photo changed:
   a. Show upload progress
   b. Upload to Storage
   c. Get download URL
   d. Update groupPhotoURL
7. Update displayName in SwiftData
8. Set syncStatus: pending
9. Sync to RTDB
10. If name changed → send system message
11. Dismiss sheet
12. GroupInfoView reloads with new values
```

**Photo Upload Flow:**
```
1. User taps group photo
2. ImagePicker appears
3. User selects photo
4. Check photo size
5. If >5MB → compress to max 5MB
6. Show upload progress (0-100%)
7. Upload to Storage: /group_photos/{groupId}/photo.jpg
8. On success → return download URL
9. On failure → show error toast with retry
10. On cancel → stop upload, revert to old photo
```

### Code Examples

**EditGroupInfoView:**
```swift
struct EditGroupInfoView: View {
    let conversation: ConversationEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var groupName: String
    @State private var groupPhoto: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0

    init(conversation: ConversationEntity) {
        self.conversation = conversation
        _groupName = State(initialValue: conversation.displayName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()

                        Button(action: { showImagePicker = true }) {
                            if let photo = groupPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "camera.fill")
                                        }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            }
                        }

                        Spacer()
                    }

                    TextField("Group Name", text: $groupName)
                        .font(.system(size: 18))

                    Text("\(groupName.count)/50 characters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Group Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .disabled(groupName.isEmpty || groupName.count > 50)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $groupPhoto)
            }
            .overlay {
                if isUploading {
                    VStack(spacing: 12) {
                        ProgressView(value: uploadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        Text("Uploading... \(Int(uploadProgress * 100))%")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }
            }
        }
    }

    private func saveChanges() async {
        let oldName = conversation.displayName

        // Update group name
        conversation.displayName = groupName
        conversation.updatedAt = Date()
        try? modelContext.save()

        // Upload new photo if changed
        if let photo = groupPhoto {
            isUploading = true

            do {
                let url = try await StorageService.shared.uploadGroupPhoto(
                    photo,
                    groupID: conversation.id,
                    progressHandler: { progress in
                        uploadProgress = progress
                    }
                )
                conversation.groupPhotoURL = url
                try? modelContext.save()
            } catch {
                // Show error toast
                print("Photo upload failed: \(error)")
            }

            isUploading = false
        }

        // Sync to RTDB
        conversation.syncStatus = .pending
        try? modelContext.save()

        Task.detached {
            try? await ConversationService.shared.syncConversationToRTDB(conversation)

            // Post system message if name changed
            if oldName != groupName {
                let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
                    for: AuthService.shared.currentUserID ?? ""
                ) ?? "Someone"

                let systemMessage = MessageEntity(
                    id: UUID().uuidString,
                    conversationID: conversation.id,
                    senderID: "system",
                    text: "\(currentUserDisplayName) changed the group name to \"\(groupName)\"",
                    createdAt: Date(),
                    status: .sent,
                    syncStatus: .synced,
                    isSystemMessage: true
                )

                try? await MessageService.shared.sendMessageToRTDB(systemMessage)
            }
        }

        dismiss()
    }
}
```

**Photo Upload with Progress:**
```swift
// StorageService extension
func uploadGroupPhoto(
    _ image: UIImage,
    groupID: String,
    progressHandler: @escaping (Double) -> Void
) async throws -> String {
    // Compress if needed
    var imageData = image.jpegData(compressionQuality: 0.8)
    if let data = imageData, data.count > 5 * 1024 * 1024 {
        // Compress to max 5MB
        imageData = image.jpegData(compressionQuality: 0.4)
    }

    guard let data = imageData else {
        throw StorageError.compressionFailed
    }

    // Upload to Storage
    let storageRef = Storage.storage().reference()
    let photoRef = storageRef.child("group_photos/\(groupID)/photo.jpg")

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    // Upload with progress
    let uploadTask = photoRef.putData(data, metadata: metadata)

    uploadTask.observe(.progress) { snapshot in
        let progress = Double(snapshot.progress?.fractionCompleted ?? 0)
        progressHandler(progress)
    }

    let _ = try await uploadTask

    // Get download URL
    let url = try await photoRef.downloadURL()
    return url.absoluteString
}
```

### Dependencies

**Required:**
- ✅ Story 3.1: Create Group Conversation (ImagePicker, StorageService)
- ✅ Story 3.2: Group Info Screen (UI integration point)
- ✅ ConversationService with RTDB sync
- ✅ MessageService for system messages

**Blocks:**
- None (independent feature)

**External:**
- Firebase Storage configured
- Storage rules allow group photo uploads

---

## Testing & Validation

### Test Procedure

1. **Access Edit Screen:**
   - Open GroupInfoView as admin
   - Tap "Edit Group Info"
   - EditGroupInfoView sheet appears
   - Current group name and photo displayed

2. **Change Group Name:**
   - Edit name: "New Group Name"
   - Character count updates: "14/50 characters"
   - Tap "Save"
   - Sheet dismisses
   - GroupInfoView shows new name
   - System message: "Alice changed the group name to "New Group Name""

3. **Change Group Photo:**
   - Tap group photo circle
   - ImagePicker appears
   - Select new photo
   - New photo displays in preview
   - Tap "Save"
   - Upload progress bar appears (0-100%)
   - Upload completes
   - Sheet dismisses
   - GroupInfoView shows new photo

4. **Validation:**
   - Try empty name → "Save" disabled
   - Try 51-character name → "Save" disabled
   - Try 1-character name → "Save" enabled
   - Try 50-character name → "Save" enabled

5. **Photo Upload Progress:**
   - Select large photo (>5MB)
   - Verify compression applied
   - Upload starts
   - Progress bar shows 0% → 100%
   - Upload completes successfully

6. **Photo Upload Error Handling:**
   - Disconnect network
   - Upload photo
   - Error toast appears: "Upload failed: Network error"
   - Retry button appears
   - Reconnect network
   - Tap retry
   - Upload succeeds

7. **Upload Cancellation:**
   - Start photo upload
   - Tap "Cancel" during upload
   - Upload stops
   - Sheet dismisses
   - Old photo retained

8. **Concurrent Edit Detection:**
   - Admin A opens EditGroupInfoView
   - Admin B changes group name
   - Admin A tries to save
   - Toast appears: "Group name was updated by another admin"
   - Option to overwrite or cancel

9. **Real-Time Sync:**
   - Admin A changes group name
   - User B (in same group) sees name update in real-time
   - ConversationListView reflects new name
   - MessageThreadView navigation bar shows new name

10. **Offline Edit:**
    - Disconnect network
    - Change group name
    - Tap "Save"
    - Changes saved locally (syncStatus: pending)
    - Reconnect network
    - Changes sync to RTDB
    - System message sent

### Success Criteria

- [ ] Builds without errors
- [ ] Runs on iOS 17+ simulator and device
- [ ] EditGroupInfoView displays current values
- [ ] Group name editing works with validation
- [ ] Group photo upload works with ImagePicker
- [ ] Upload progress bar displays (0-100%)
- [ ] Large photos compressed before upload
- [ ] Upload errors handled with retry
- [ ] System message created for name changes
- [ ] Real-time sync to all group members
- [ ] Concurrent edit conflict detection works
- [ ] Offline edits queued and synced
- [ ] Admin-only enforcement (button hidden for non-admins)

---

## References

**Architecture Docs:**
- `docs/architecture/unified-project-structure.md` - File organization

**PRD Sections:**
- `docs/prd.md` - Epic 3: Group Chat

**Epic Documentation:**
- `docs/epics/epic-3-group-chat.md` - Story 3.4 specification (lines 935-1110)
- `docs/epics/epic-3-COMPONENT-SPECS.md` - ImagePicker component

**Related Stories:**
- Story 3.1: Create Group Conversation (ImagePicker, StorageService)
- Story 3.2: Group Info Screen (UI integration)

---

## Notes & Considerations

### Implementation Notes

**Admin-Only Editing:**
- Check `conversation.adminUserIDs.contains(AuthService.shared.currentUserID)`
- Hide "Edit Group Info" button if not admin
- Enforce server-side via RTDB rules

**System Messages:**
- Only send if name actually changed (compare `oldName != newName`)
- Text format: "{Admin} changed the group name to "{NewName}""
- Don't send system message for photo-only changes

**Photo Compression:**
- Max photo size: 5MB
- Compression quality: 0.8 (or 0.4 if >5MB)
- Target max dimensions: 1024x1024

### Edge Cases

- User changes name but cancels → no changes saved
- User selects photo but cancels picker → old photo retained
- Upload fails mid-progress → show error, allow retry
- Network drops during upload → queue for retry
- Concurrent edits by two admins → detect and show conflict
- User removes photo library permission → graceful fallback
- Group deleted while editing → handle error

### Performance Considerations

- Compress photos asynchronously (don't block UI)
- Show upload progress to prevent perceived hang
- Cache current group photo with AsyncImage
- Debounce character count updates
- Use Task.detached for RTDB sync (off main thread)

### Security Considerations

- Only admins can edit group info (RTDB rules enforce)
- Validate group name length server-side (1-50 chars)
- Sanitize group name (prevent injection)
- Storage rules restrict uploads to authenticated users
- Validate photo MIME type (jpeg/png only)

---

## Dev Notes

**CRITICAL: This section contains ALL implementation context needed. Developer should NOT need to read external docs.**

### EditGroupInfoView Implementation Pattern
[Source: epic-3-group-chat.md lines 961-1102]

**Sheet Presentation from GroupInfoView:**
```swift
// In GroupInfoView
@State private var showEditSheet = false

// "Edit Group Info" button (admin-only)
if isAdmin {
    Button("Edit Group Info") {
        showEditSheet = true
    }
    .buttonStyle(.bordered)
}

.sheet(isPresented: $showEditSheet) {
    NavigationStack {
        EditGroupInfoView(conversation: conversation)
    }
}
```

**EditGroupInfoView Structure:**
```swift
struct EditGroupInfoView: View {
    let conversation: ConversationEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var groupName: String
    @State private var groupPhoto: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0

    init(conversation: ConversationEntity) {
        self.conversation = conversation
        _groupName = State(initialValue: conversation.displayName ?? "")
    }

    // Form with photo, name, character count, save/cancel buttons
}
```

### Photo Upload with Progress and Compression
[Source: epic-3-group-chat.md lines 1058-1069, Story 3.1]

**StorageService.uploadGroupPhoto() with Progress:**
```swift
// In StorageService (ALREADY EXISTS from Story 3.1)
func uploadGroupPhoto(
    _ image: UIImage,
    groupID: String,
    progressHandler: @escaping (Double) -> Void
) async throws -> String {
    // Compress if needed
    var imageData = image.jpegData(compressionQuality: 0.8)
    if let data = imageData, data.count > 5 * 1024 * 1024 {
        // Compress to max 5MB
        imageData = image.jpegData(compressionQuality: 0.4)
    }

    guard let data = imageData else {
        throw StorageError.compressionFailed
    }

    // Upload to Storage
    let storageRef = Storage.storage().reference()
    let photoRef = storageRef.child("group_photos/\(groupID)/photo.jpg")

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    // Upload with progress
    let uploadTask = photoRef.putData(data, metadata: metadata)

    uploadTask.observe(.progress) { snapshot in
        let progress = Double(snapshot.progress?.fractionCompleted ?? 0)
        progressHandler(progress)
    }

    let _ = try await uploadTask

    // Get download URL
    let url = try await photoRef.downloadURL()
    return url.absoluteString
}
```

**Progress UI Overlay:**
```swift
.overlay {
    if isUploading {
        VStack(spacing: 12) {
            ProgressView(value: uploadProgress, total: 1.0)
                .progressViewStyle(.linear)
            Text("Uploading... \(Int(uploadProgress * 100))%")
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}
```

### System Message for Name Change Only
[Source: epic-3-group-chat.md lines 1078-1096]

**CRITICAL: Only send system message if name changed**

```swift
private func saveChanges() async {
    let oldName = conversation.displayName

    // Update group name
    conversation.displayName = groupName
    conversation.updatedAt = Date()
    try? modelContext.save()

    // Upload new photo if changed
    if let photo = groupPhoto {
        isUploading = true

        do {
            let url = try await StorageService.shared.uploadGroupPhoto(
                photo,
                groupID: conversation.id,
                progressHandler: { progress in
                    uploadProgress = progress
                }
            )
            conversation.groupPhotoURL = url
            try? modelContext.save()
        } catch {
            // Show error toast
            print("Photo upload failed: \(error)")
        }

        isUploading = false
    }

    // Sync to RTDB
    conversation.syncStatus = .pending
    try? modelContext.save()

    Task.detached {
        try? await ConversationService.shared.syncConversationToRTDB(conversation)

        // Post system message ONLY if name changed
        if oldName != groupName {
            let currentUserDisplayName = try await ConversationService.shared.fetchDisplayName(
                for: AuthService.shared.currentUserID ?? ""
            ) ?? "Someone"

            let systemMessage = MessageEntity(
                id: UUID().uuidString,
                conversationID: conversation.id,
                senderID: "system",
                text: "\(currentUserDisplayName) changed the group name to \"\(groupName)\"",
                createdAt: Date(),
                status: .sent,
                syncStatus: .synced,
                isSystemMessage: true
            )

            try? await MessageService.shared.sendMessageToRTDB(systemMessage)
        }
    }

    dismiss()
}
```

**System Message Format:**
- Name change: "{AdminName} changed the group name to \"{NewName}\""
- **NO system message for photo-only changes**

### Concurrent Edit Conflict Detection
[Source: epic-3-group-chat.md lines 1048-1100]

**Pattern: Check if name changed by another admin**

```swift
private func saveChanges() async {
    // Before saving, check if another admin changed the name
    let currentGroupName = conversation.displayName

    // Fetch latest from RTDB (optional - for conflict detection)
    let latestSnapshot = try? await Database.database().reference()
        .child("conversations")
        .child(conversation.id)
        .child("groupName")
        .getData()

    let latestName = latestSnapshot?.value as? String

    if let latestName = latestName, latestName != currentGroupName {
        // Another admin changed the name
        showConflictToast = true
        conflictMessage = "Group name was updated by another admin"
        // Option 1: Overwrite anyway
        // Option 2: Cancel and reload
        return
    }

    // Proceed with save...
}
```

**Conflict Resolution Options:**
1. Show toast: "Group name was updated by another admin"
2. Provide buttons: "Overwrite" or "Cancel"
3. If overwrite → proceed with save
4. If cancel → dismiss sheet, reload GroupInfoView

### Character Count Validation
[Source: epic-3-group-chat.md lines 961-1102]

**Group Name Validation:**
- **Minimum:** 1 character (non-empty)
- **Maximum:** 50 characters
- **Real-time character count:** Display "\(groupName.count)/50 characters"

```swift
TextField("Group Name", text: $groupName)
    .font(.system(size: 18))

Text("\(groupName.count)/50 characters")
    .font(.system(size: 12))
    .foregroundColor(.secondary)

// Save button disabled if invalid
Button("Save") {
    Task { await saveChanges() }
}
.disabled(groupName.isEmpty || groupName.count > 50)
```

### ImagePicker Integration
[Source: Story 3.1, epic-3-COMPONENT-SPECS.md]

**ImagePicker Component (Already Created in Story 3.1):**
```swift
// In EditGroupInfoView
@State private var showImagePicker = false
@State private var groupPhoto: UIImage?

Button(action: { showImagePicker = true }) {
    if let photo = groupPhoto {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: 100, height: 100)
            .clipShape(Circle())
    } else {
        AsyncImage(url: URL(string: conversation.groupPhotoURL ?? "")) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle().fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "camera.fill")
                }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }
}

.sheet(isPresented: $showImagePicker) {
    ImagePicker(image: $groupPhoto)
}
```

### Upload Cancellation Pattern
[Source: epic-3-group-chat.md lines 1058-1069]

**Allow Upload Cancellation:**
```swift
@State private var uploadTask: StorageUploadTask?

// During upload
uploadTask = photoRef.putData(data, metadata: metadata)

// Cancel button in overlay
Button("Cancel Upload") {
    uploadTask?.cancel()
    isUploading = false
    groupPhoto = nil  // Revert to old photo
}
```

### File Modification Order

**CRITICAL: Follow this exact sequence:**

1. ✅ Update `ConversationEntity.swift` - **Already done in Story 3.1**
2. ✅ Create `ImagePicker.swift` - **Already done in Story 3.1**
3. ✅ Update `StorageService.swift` (uploadGroupPhoto method) - **Already done in Story 3.1**
4. Create `EditGroupInfoView.swift` (main implementation)
5. Update `GroupInfoView.swift` (add "Edit Group Info" button)

### Testing Standards

**Manual Testing Required (No Unit Tests for MVP):**
- Test name change (valid, empty, 51 chars)
- Test photo upload (small, large, 5MB+, upload failure, cancellation)
- Test upload progress (0-100%)
- Test concurrent edit conflict (two admins editing simultaneously)
- Test offline edit (queue for sync)
- Test system message (name change only, not photo-only)

**CRITICAL Edge Cases:**
1. Empty name → "Save" disabled
2. 51+ character name → "Save" disabled
3. Photo upload fails → show error toast with retry
4. Cancel during upload → revert to old photo
5. Concurrent edit by another admin → show conflict toast
6. Offline edit → queued, synced when online
7. Photo-only change → NO system message sent

**Upload Error Scenarios:**
- Network error → "Upload failed: Network error" + retry button
- Storage quota exceeded → "Upload failed: Storage quota exceeded"
- Permission denied → "Upload failed: Permission denied"
- Large file → Compress before upload (max 5MB)

---

## Metadata

**Created by:** @sm (Scrum Master Bob)
**Created date:** 2025-10-21
**Last updated:** 2025-10-21
**Sprint:** Day 2-3 of 7-day sprint
**Epic:** Epic 3: Group Chat
**Story points:** 2
**Priority:** P1

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-21 | 1.0 | Initial story creation | @sm (Scrum Master Bob) |
| 2025-10-21 | 1.1 | Added Dev Notes section per template compliance | @po (Product Owner Sarah) |

---

## Dev Agent Record

**This section is populated by the @dev agent during implementation.**

### Agent Model Used

*Agent model name and version will be recorded here by @dev*

### Debug Log References

*Links to debug logs or traces generated during development will be recorded here by @dev*

### Completion Notes

*Notes about task completion and any issues encountered will be recorded here by @dev*

### File List

*All files created, modified, or affected during story implementation will be listed here by @dev*

---

## QA Results

**This section is populated by the @qa agent after reviewing the completed story implementation.**

*QA validation results, test outcomes, and any issues found will be recorded here by @qa*

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review
- [ ] **Ready** - Story reviewed and ready for development
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated

**Current Status:** Draft
