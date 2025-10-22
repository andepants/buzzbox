# Epic 3: Component Specifications

**Date:** 2025-10-21
**Purpose:** Full specifications for prerequisite components
**Status:** Ready for Implementation

---

## Overview

This document provides complete implementation specifications for the two components required by Epic 3 Story 3.1:

1. **ImagePicker** - UIImagePickerController wrapper for SwiftUI
2. **ParticipantPickerView** - Multi-select user picker for group creation

---

## Component 1: ImagePicker

### File Location
```
sorted/Core/Components/ImagePicker.swift
```

### Purpose
Reusable SwiftUI wrapper around UIImagePickerController for photo library access. Used for group photo and profile picture selection.

### Dependencies
- UIKit (UIImagePickerController)
- SwiftUI (UIViewControllerRepresentable)
- Info.plist: `NSPhotoLibraryUsageDescription` key

### Full Implementation

```swift
/// ImagePicker.swift
///
/// SwiftUI wrapper for UIImagePickerController
/// Allows users to select images from photo library
///
/// Created: 2025-10-21 (Epic 3 Prerequisite)

import SwiftUI
import UIKit

/// SwiftUI wrapper for UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    /// Binding to store selected image
    @Binding var image: UIImage?

    /// Environment dismiss action
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        /// Called when user selects an image
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Get selected image
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }

            // Dismiss picker
            parent.dismiss()
        }

        /// Called when user cancels
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    struct ImagePickerPreview: View {
        @State private var selectedImage: UIImage?
        @State private var showPicker = false

        var body: some View {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay {
                            Text("No image selected")
                                .foregroundColor(.secondary)
                        }
                }

                Button("Select Image") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .sheet(isPresented: $showPicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    return ImagePickerPreview()
}
```

### Usage Examples

#### Example 1: Group Photo Selection (GroupCreationView)

```swift
struct GroupCreationView: View {
    @State private var groupPhoto: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        Button(action: { showImagePicker = true }) {
            if let photo = groupPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.gray)
                    }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $groupPhoto)
        }
    }
}
```

#### Example 2: Profile Picture Upload (ProfileView)

```swift
struct ProfileView: View {
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        VStack {
            Button(action: { showImagePicker = true }) {
                AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            }

            Text("Tap to change photo")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
        }
        .onChange(of: profileImage) { _, newImage in
            if let image = newImage {
                Task {
                    await uploadProfileImage(image)
                }
            }
        }
    }
}
```

### Info.plist Configuration

**CRITICAL:** Add this key to `sorted/sorted/Info.plist` or the app will crash:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Sorted needs access to your photo library to upload profile pictures and group photos.</string>
```

### Error Handling

**Permission Denied:**
- ImagePicker will not show if permission denied
- iOS shows system alert asking for permission
- No additional handling needed in ImagePicker

**No Image Selected:**
- User taps "Cancel" → `imagePickerControllerDidCancel` called
- Binding remains unchanged
- Sheet dismisses automatically

### Testing Checklist

- [ ] Open ImagePicker → photo library appears
- [ ] Select image → binding updated, sheet dismisses
- [ ] Cancel picker → sheet dismisses, binding unchanged
- [ ] Permission denied → system alert appears
- [ ] Selected image displays correctly in parent view
- [ ] Works on iPhone and iPad
- [ ] No memory leaks (check with Instruments)

### Time Estimate
**Implementation:** 10 minutes
**Testing:** 5 minutes
**Total:** 15 minutes

---

## Component 2: ParticipantPickerView

### File Location
```
sorted/Features/Chat/Views/Components/ParticipantPickerView.swift
```

### Purpose
Multi-select user picker for group creation. Fetches all users from Firestore and allows selection of multiple participants with checkmark indicators.

### Dependencies
- SwiftUI
- Firebase Firestore
- Kingfisher or AsyncImage (for profile pictures)
- AuthService (to filter out current user)

### Full Implementation

```swift
/// ParticipantPickerView.swift
///
/// Multi-select user picker for group participant selection
/// Fetches users from Firestore and allows multi-selection
///
/// Created: 2025-10-21 (Epic 3 Prerequisite)

@preconcurrency import FirebaseFirestore
import SwiftUI

/// Multi-select participant picker for group creation
struct ParticipantPickerView: View {
    /// Binding to store selected user IDs
    @Binding var selectedUserIDs: Set<String>

    // MARK: - State

    @State private var users: [UserPreview] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    // MARK: - Body

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading users...")
                        Spacer()
                    }
                }
            } else if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            } else if filteredUsers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Users Found",
                        systemImage: "person.slash",
                        description: Text("No users available to add to group")
                    )
                }
            } else {
                Section {
                    ForEach(filteredUsers) { user in
                        ParticipantRow(
                            user: user,
                            isSelected: selectedUserIDs.contains(user.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(for: user.id)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search users")
        .task {
            await loadUsers()
        }
    }

    // MARK: - Filtered Users

    private var filteredUsers: [UserPreview] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Methods

    /// Toggle user selection
    private func toggleSelection(for userID: String) {
        if selectedUserIDs.contains(userID) {
            selectedUserIDs.remove(userID)
        } else {
            selectedUserIDs.insert(userID)
        }
    }

    /// Load users from Firestore
    private func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let firestore = Firestore.firestore()
            let snapshot = try await firestore.collection("users").getDocuments()

            // Get current user ID to filter out
            let currentUserID = AuthService.shared.currentUserID ?? ""

            // Convert documents to UserPreview objects
            let fetchedUsers = snapshot.documents.compactMap { doc -> UserPreview? in
                guard let data = doc.data() as? [String: Any],
                      let email = data["email"] as? String,
                      let displayName = data["displayName"] as? String,
                      doc.documentID != currentUserID else {
                    return nil
                }

                return UserPreview(
                    id: doc.documentID,
                    email: email,
                    displayName: displayName,
                    photoURL: data["photoURL"] as? String
                )
            }

            // Sort alphabetically by display name
            users = fetchedUsers.sorted { $0.displayName < $1.displayName }

        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - ParticipantRow

/// Row view for a single participant
private struct ParticipantRow: View {
    let user: UserPreview
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))

                Text(user.email)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 24))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UserPreview Model

/// Lightweight user model for participant selection
struct UserPreview: Identifiable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: String?
}

// MARK: - Preview

#Preview {
    NavigationStack {
        struct ParticipantPickerPreview: View {
            @State private var selectedUserIDs: Set<String> = []

            var body: some View {
                VStack {
                    ParticipantPickerView(selectedUserIDs: $selectedUserIDs)

                    if !selectedUserIDs.isEmpty {
                        Text("Selected: \(selectedUserIDs.count) users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }

        return ParticipantPickerPreview()
            .navigationTitle("Select Participants")
    }
}
```

### Usage Example (GroupCreationView)

```swift
struct GroupCreationView: View {
    @State private var selectedUserIDs: Set<String> = []
    @State private var groupName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)

                    Text("\(selectedUserIDs.count) participants selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Select Participants") {
                    ParticipantPickerView(selectedUserIDs: $selectedUserIDs)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty || selectedUserIDs.count < 2)
                }
            }
        }
    }

    private func createGroup() {
        // Group creation logic
    }
}
```

### Data Flow

```
1. View appears
   ↓
2. .task { await loadUsers() }
   ↓
3. Firestore query: collection("users").getDocuments()
   ↓
4. Filter out current user
   ↓
5. Convert to UserPreview objects
   ↓
6. Sort alphabetically
   ↓
7. Display in List
   ↓
8. User taps row → toggleSelection()
   ↓
9. selectedUserIDs binding updated
   ↓
10. Parent view (GroupCreationView) receives selected IDs
```

### Performance Considerations

**Large User Lists (100+ users):**
- Firestore query fetches ALL users (acceptable for MVP)
- Consider pagination for production (future enhancement)
- Search/filter helps narrow results

**Optimization (Post-MVP):**
```swift
// Paginated query (future)
let query = firestore.collection("users")
    .limit(to: 50)
    .start(afterDocument: lastDocument)
```

### Error Handling

**Firestore Query Fails:**
- Shows error message in UI
- User can pull to refresh (future enhancement)
- Logs error to console

**No Users Found:**
- Shows ContentUnavailableView
- Explains no users available

**Current User Missing:**
- Gracefully handles nil currentUserID
- Defaults to empty string, filters nothing

### Testing Checklist

- [ ] Loads all users from Firestore
- [ ] Current user NOT in list
- [ ] Users sorted alphabetically
- [ ] Profile pictures load correctly
- [ ] Placeholder shows for users without photos
- [ ] Tap row → checkmark appears
- [ ] Tap again → checkmark disappears
- [ ] Multiple selections work
- [ ] Search filters correctly
- [ ] selectedUserIDs binding updates
- [ ] Loading state shows while fetching
- [ ] Error state shows on failure
- [ ] Empty state shows if no users

### Time Estimate
**Implementation:** 25 minutes
**Testing:** 5 minutes
**Total:** 30 minutes

---

## Integration Checklist

Before implementing Story 3.1:

- [ ] Create `ImagePicker.swift` (15 min)
  - [ ] Add to `sorted/Core/Components/`
  - [ ] Add NSPhotoLibraryUsageDescription to Info.plist
  - [ ] Test image selection

- [ ] Create `ParticipantPickerView.swift` (30 min)
  - [ ] Add to `sorted/Features/Chat/Views/Components/`
  - [ ] Test user loading from Firestore
  - [ ] Test multi-selection

- [ ] Verify components work
  - [ ] ImagePicker returns UIImage correctly
  - [ ] ParticipantPickerView returns Set<String> of user IDs
  - [ ] Both compile without errors

- [ ] Proceed to Story 3.1 main tasks
  - [ ] GroupCreationView implementation
  - [ ] RTDB sync
  - [ ] Group photo upload

---

## Summary

**Total Prerequisite Time:** 45 minutes
- ImagePicker: 15 minutes
- ParticipantPickerView: 30 minutes

**Dependencies:**
- Info.plist: NSPhotoLibraryUsageDescription
- Firestore: `/users` collection access
- AuthService: currentUserID property

**Next Steps:**
1. Apply Fix Patches from `epic-3-FIX-PATCHES.md`
2. Implement these two components
3. Begin Story 3.1 implementation

---

**Status:** Ready for Implementation
**Complexity:** Low (standard SwiftUI patterns)
**Risk:** Low (well-defined requirements)
