# Epic 4: Media Sharing (Images, Videos, Files)

**Phase:** Day 2-3 (Extended Messaging)
**Priority:** P1 (High - Core Feature)
**Original Estimate:** 4-5 hours | **Revised Estimate:** 2.5 hours (MVP), 5 hours (Full)
**Epic Owner:** Development Team Lead
**Dependencies:** Epic 2 (One-on-One Chat), Epic 3 (Group Chat)

---

## 📋 Document Audit Notice

**Audit Date:** 2025-10-22
**Auditor:** Product Owner (Sarah)
**Status:** Updated to reflect current implementation state

**Key Changes:**
- ✅ Added "Current Implementation Status" section (line 32)
- ✅ Updated all stories with implementation notes (✅ Done, 🟡 Partial, ❌ Not Started)
- ✅ Revised time estimates based on completed work (35% done)
- ✅ Added MVP vs Full scope recommendations
- ✅ Documented existing AttachmentEntity and StorageService implementations
- ✅ Marked completed technical tasks throughout
- ✅ Added strategic recommendations for Stories 4.5-4.6 (defer to Phase 2)

**Next Actions:**
1. Review and approve MVP scope (Stories 4.1-4.4 only)
2. Confirm video/file sharing can be deferred
3. Decide: CachedAsyncImage wrapper vs direct KFImage usage
4. Allocate 2.5 hours for MVP completion

---

## Overview

Enable users to share images, videos, and files within conversations. Includes media picker integration, Firebase Storage uploads with progress tracking, image caching with Kingfisher, thumbnail generation, and media gallery viewer with zoom/pan gestures.

---

## What This Epic Delivers

- ✅ Image sharing with PHPicker (photos + camera)
- ✅ Video sharing with file size limits (max 100MB)
- ✅ File sharing (PDFs, documents) with type restrictions
- ✅ Firebase Storage uploads with progress indicators
- ✅ Image caching with Kingfisher for performance
- ✅ Thumbnail generation for videos and large images
- ✅ Full-screen media viewer with zoom/pan gestures
- ✅ Download media to Photos library
- ✅ Offline support (queue uploads, cache downloads)
- ✅ Media compression before upload (reduce bandwidth)

---

## 🔧 Current Implementation Status

**Last Updated:** 2025-10-22

### ✅ Already Implemented (Foundation Complete)

**SwiftData Models:**
- ✅ `AttachmentEntity` - Enhanced model with upload tracking, local/remote URLs
  - Location: `buzzbox/Core/Models/AttachmentEntity.swift`
  - Features: `uploadStatus`, `uploadProgress`, `uploadError`, `localURL`
  - Types: `.image`, `.video`, `.audio`, `.document`

**Firebase Services:**
- ✅ `StorageService` - Basic image upload with compression
  - Location: `buzzbox/Core/Services/StorageService.swift`
  - Methods: `uploadImage(_:path:)`, `uploadGroupPhoto(_:groupID:)`, `deleteImage(at:)`
  - Compression: Auto-compress to 2048x2048, 85% quality, <500KB
  - Validation: 5MB max file size

**Image Pickers:**
- ✅ `ImagePicker` wrapper (UIKit) - Used in ProfileView, GroupCreationView
- ✅ `PhotosPicker` integration - Photo library access (iOS 16+)
- ✅ Kingfisher caching configured in AppContainer

**Group Photo Upload:**
- ✅ Group photo upload with progress tracking in GroupCreationView
- ✅ Profile picture upload in ProfileView

### 🚧 Partially Implemented (Needs Integration)

**Message Attachments:**
- 🟡 `MessageEntity.attachments` relationship exists but not used in UI
- 🟡 `AttachmentEntity` model ready but no message composer integration
- 🟡 Upload progress tracking architecture exists but no UI

**Image Caching:**
- 🟡 Kingfisher configured but not used consistently
- 🟡 Some views use `AsyncImage` instead of `KFImage` (no caching)

### ❌ Not Yet Implemented (Remaining Work)

**Story 4.1 - Image Picker Integration:**
- ❌ CameraView wrapper for camera access
- ❌ Attachment menu in MessageComposerView
- ❌ Image thumbnail previews in composer
- ❌ Send images with messages

**Story 4.2 - Upload Progress:**
- ❌ Progress callback in `uploadImage()` for real-time tracking
- ❌ Parallel upload management (max 3 concurrent)
- ❌ Retry button UI for failed uploads
- ❌ Offline upload queue

**Story 4.3 - Image Caching:**
- ❌ `CachedAsyncImage` wrapper component
- ❌ Replace all `AsyncImage` with cached version
- ❌ Image display in MessageBubbleView

**Story 4.4 - Media Viewer (CRITICAL UX):**
- ❌ Full-screen media viewer component
- ❌ Pinch-to-zoom gestures
- ❌ Swipe-to-dismiss interaction
- ❌ Share sheet integration
- ❌ Save to Photos library

**Story 4.5 - Video Sharing:**
- ❌ Video upload with progress tracking
- ❌ Video thumbnail generation (AVAsset)
- ❌ VideoPlayerView for inline playback
- ❌ 100MB file size limit enforcement

**Story 4.6 - File Sharing:**
- ❌ DocumentPicker wrapper
- ❌ File upload support (PDF, DOC, etc.)
- ❌ File download and viewer integration

### 📊 Implementation Progress

| Component | Status | Priority | Estimated Time |
|-----------|--------|----------|----------------|
| AttachmentEntity Model | ✅ Complete | - | - |
| StorageService Foundation | ✅ Complete | - | - |
| Image Pickers | ✅ Complete | - | - |
| Message Composer Integration | ❌ Not Started | P0 | 45 min |
| CameraView Wrapper | ❌ Not Started | P1 | 30 min |
| Upload Progress UI | ❌ Not Started | P1 | 45 min |
| Media Viewer | ❌ Not Started | P0 | 90 min |
| Video Sharing | ❌ Not Started | P2 | 90 min |
| File Sharing | ❌ Not Started | P3 | 60 min |

**Overall Epic Progress:** 🟡 **~35% Complete** (Foundation + Models)

---

### iOS-Specific Media Sharing Patterns

**Media sharing is heavily iOS-specific - follow native iOS patterns:**

- ✅ **Photo Permissions:** CRITICAL - NSPhotoLibraryUsageDescription and NSCameraUsageDescription in Info.plist
- ✅ **PhotosPicker:** Use native `PhotosPicker` (iOS 16+) for modern photo selection
- ✅ **Camera Integration:** Wrap `UIImagePickerController` for camera access
- ✅ **Pinch-to-Zoom:** Use `MagnificationGesture()` for full-screen image viewer
- ✅ **Swipe-to-Dismiss:** Interactive dismissal with drag gesture in media viewer
- ✅ **Progress Indicators:** Circular progress for uploads (0-100%)
- ✅ **Share Sheet:** Use native `UIActivityViewController` for sharing
- ✅ **Photo Library Saving:** Request permission, handle denial gracefully
- ✅ **Kingfisher Caching:** Configure cache limits for mobile (500MB disk max)
- ✅ **Memory Management:** Release large images from memory after viewing

---

## User Stories

### Story 4.1: Image Picker and Camera Integration
**As a user, I want to attach images to messages so I can share photos with others.**

**Acceptance Criteria:**
- [ ] Tap "+" button in message composer shows attachment menu
- [ ] "Photo Library" option opens PHPicker (multi-select enabled)
- [ ] "Camera" option opens camera (requires permission)
- [ ] Selected images show as thumbnails in composer
- [ ] User can remove selected images before sending
- [ ] Tapping send uploads images and sends message
- [ ] Images display in chat thread with loading indicators

**Technical Tasks:**

> **✅ IMPLEMENTATION NOTE:** AttachmentEntity already exists at `buzzbox/Core/Models/AttachmentEntity.swift`
> **Status:** Foundation complete, needs minor enhancements for video/image metadata

1. ✅ **DONE:** MessageEntity attachment relationship exists:
   ```swift
   @Model
   final class MessageEntity {
       @Attribute(.unique) var id: String
       var conversationID: String
       var senderID: String
       var text: String
       var createdAt: Date
       var status: MessageStatus
       var syncStatus: SyncStatus
       @Relationship(deleteRule: .cascade) var attachments: [AttachmentEntity] // ✅ Already implemented
       var isSystemMessage: Bool
       var readBy: [String: Date]
   }
   ```

2. ✅ **DONE:** AttachmentEntity model (current implementation):
   ```swift
   @Model
   final class AttachmentEntity {
       @Attribute(.unique) var id: String
       var type: AttachmentType // .image, .video, .audio, .document
       var url: String? // Firebase Storage URL
       var localURL: String? // Local file path
       var thumbnailURL: String? // Thumbnail for videos/large images
       var fileSize: Int64
       var mimeType: String
       var fileName: String
       var uploadStatus: UploadStatus // .pending, .uploading, .completed, .failed
       var uploadProgress: Double // 0.0 - 1.0
       var uploadError: String?
       var createdAt: Date

       // 🟡 TODO: Add these properties for video/image metadata:
       // var width: Int?
       // var height: Int?
       // var duration: TimeInterval? // For videos

       @Relationship(deleteRule: .nullify, inverse: \MessageEntity.attachments)
       var message: MessageEntity?
   }
   ```

3. ⚠️ **TODO:** Enhance AttachmentEntity with metadata properties:
   ```swift
   // Add to AttachmentEntity.swift:
   /// Image/video width in pixels
   var width: Int?

   /// Image/video height in pixels
   var height: Int?

   /// Video duration in seconds
   var duration: TimeInterval?
   ```

4. ✅ **DONE:** PhotosPicker already used in ProfileView and GroupCreationView:
   ```swift
   // Example from ProfileView.swift
   PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
       // ... UI content
   }
   ```

5. ⚠️ **TODO:** Create AttachmentPickerView for MessageComposerView:
   ```swift
   import PhotosUI

   struct AttachmentPickerView: View {
       @Binding var selectedItems: [PhotosPickerItem]
       @Binding var selectedImages: [UIImage]

       var body: some View {
           PhotosPicker(
               selection: $selectedItems,
               maxSelectionCount: 10,
               matching: .any(of: [.images, .videos])
           ) {
               Label("Photo Library", systemImage: "photo.on.rectangle")
           }
           .onChange(of: selectedItems) { _, newItems in
               Task {
                   selectedImages = []
                   for item in newItems {
                       if let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) {
                           selectedImages.append(image)
                       }
                   }
               }
           }
       }
   }
   ```

6. ⚠️ **TODO:** Create CameraView wrapper (UIKit):
   ```swift
   import UIKit

   struct CameraView: UIViewControllerRepresentable {
       @Binding var image: UIImage?
       @Environment(\.dismiss) private var dismiss

       func makeUIViewController(context: Context) -> UIImagePickerController {
           let picker = UIImagePickerController()
           picker.sourceType = .camera
           picker.delegate = context.coordinator
           return picker
       }

       func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

       func makeCoordinator() -> Coordinator {
           Coordinator(self)
       }

       class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
           let parent: CameraView

           init(_ parent: CameraView) {
               self.parent = parent
           }

           func imagePickerController(
               _ picker: UIImagePickerController,
               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
           ) {
               if let image = info[.originalImage] as? UIImage {
                   parent.image = image
               }
               parent.dismiss()
           }

           func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
               parent.dismiss()
           }
       }
   }
   ```

7. ⚠️ **TODO:** Update MessageComposerView to show attachment menu:
   ```swift
   struct MessageComposerView: View {
       @Binding var text: String
       var onSend: () async -> Void

       @State private var selectedPhotosItems: [PhotosPickerItem] = []
       @State private var selectedImages: [UIImage] = []
       @State private var showCamera = false
       @State private var showAttachmentMenu = false

       var body: some View {
           VStack(spacing: 8) {
               // Selected images preview
               if !selectedImages.isEmpty {
                   ScrollView(.horizontal, showsIndicators: false) {
                       HStack(spacing: 8) {
                           ForEach(selectedImages.indices, id: \.self) { index in
                               ZStack(alignment: .topTrailing) {
                                   Image(uiImage: selectedImages[index])
                                       .resizable()
                                       .scaledToFill()
                                       .frame(width: 80, height: 80)
                                       .clipShape(RoundedRectangle(cornerRadius: 8))

                                   Button {
                                       selectedImages.remove(at: index)
                                   } label: {
                                       Image(systemName: "xmark.circle.fill")
                                           .foregroundColor(.white)
                                           .background(Circle().fill(Color.black.opacity(0.6)))
                                   }
                                   .padding(4)
                               }
                           }
                       }
                       .padding(.horizontal)
                   }
                   .frame(height: 88)
               }

               HStack(spacing: 12) {
                   // Attachment button
                   Button {
                       showAttachmentMenu = true
                   } label: {
                       Image(systemName: "plus.circle.fill")
                           .font(.system(size: 28))
                           .foregroundColor(.blue)
                   }

                   // Text input
                   TextField("Message", text: $text, axis: .vertical)
                       .textFieldStyle(.roundedBorder)
                       .lineLimit(1...5)

                   // Send button
                   Button {
                       Task { await onSend() }
                   } label: {
                       Image(systemName: "arrow.up.circle.fill")
                           .font(.system(size: 28))
                           .foregroundColor(canSend ? .blue : .gray)
                   }
                   .disabled(!canSend)
               }
               .padding(.horizontal)
               .padding(.vertical, 8)
           }
           .background(Color(.systemBackground))
           .confirmationDialog("Attach Media", isPresented: $showAttachmentMenu) {
               PhotosPicker(
                   selection: $selectedPhotosItems,
                   maxSelectionCount: 10,
                   matching: .any(of: [.images, .videos])
               ) {
                   Label("Photo Library", systemImage: "photo.on.rectangle")
               }

               Button("Camera") {
                   showCamera = true
               }

               Button("Cancel", role: .cancel) {}
           }
           .sheet(isPresented: $showCamera) {
               CameraView(image: $cameraImage)
           }
           .onChange(of: selectedPhotosItems) { _, newItems in
               Task {
                   for item in newItems {
                       if let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) {
                           selectedImages.append(image)
                       }
                   }
                   selectedPhotosItems = []
               }
           }
           .onChange(of: cameraImage) { _, newImage in
               if let newImage = newImage {
                   selectedImages.append(newImage)
                   cameraImage = nil
               }
           }
       }

       @State private var cameraImage: UIImage?

       private var canSend: Bool {
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
       }
   }
   ```

8. ✅ **DONE:** Camera permission in Info.plist (completed in Epic 0)
   - `NSCameraUsageDescription`
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription` (for saving)

**iOS Mobile Considerations:**
- **Photo Picker (iOS 16+):**
  - Use `PhotosPicker` with `.photoLibrary` selection limit
  - Multi-select up to 10 images: `maxSelectionCount: 10`
  - Handle permission denial: Show `.alert()` with link to Settings
- **Camera Integration:**
  - Wrap `UIImagePickerController` with `UIViewControllerRepresentable`
  - Check camera availability: `UIImagePickerController.isSourceTypeAvailable(.camera)`
  - Handle camera permission denial gracefully
- **Image Preview:**
  - Show selected images as scrollable thumbnails (80x80pt)
  - Tap X button to remove image before sending
  - Use `.clipShape(RoundedRectangle(cornerRadius: 8))` for thumbnails
- **Keyboard Interaction:**
  - Keyboard should NOT dismiss when selecting images
  - Show image picker as `.confirmationDialog()` first, then `.sheet()` for picker
- **Accessibility:**
  - Label image thumbnails with "Selected image 1 of 3, double tap to remove"
  - Announce image selection count changes to VoiceOver

**References:**
- SwiftData Implementation Guide Section 3.4 (AttachmentEntity)
- PRD Epic 4: Media Sharing

---

### Story 4.2: Firebase Storage Upload with Progress
**As a user, I want to see upload progress when sending media so I know it's working.**

**Acceptance Criteria:**
- [ ] Uploaded images compressed before upload (max 2048x2048, 85% quality)
- [ ] Upload progress shown as circular indicator (0-100%)
- [ ] Multiple images upload in parallel (max 3 concurrent)
- [ ] Failed uploads show retry button
- [ ] Uploaded URLs stored in Firestore with message
- [ ] Images download and cache automatically in recipient's chat

**Technical Tasks:**

> **✅ IMPLEMENTATION NOTE:** StorageService already exists at `buzzbox/Core/Services/StorageService.swift`
> **Status:** Basic image upload complete, needs progress tracking and video support

1. ✅ **DONE:** StorageService foundation exists with these methods:
   ```swift
   // Current implementation in StorageService.swift
   final class StorageService {
       private let storage = Storage.storage()

       // ✅ IMPLEMENTED: Basic image upload
       func uploadImage(_ image: UIImage, path: String) async throws -> URL {
           // Compresses to 2048x2048, 85% quality, <500KB
           // Returns HTTPS download URL
       }

       // ✅ IMPLEMENTED: Group photo upload
       func uploadGroupPhoto(_ image: UIImage, groupID: String) async throws -> String {
           // Uploads to group_photos/{groupID}/photo.jpg
       }

       // ✅ IMPLEMENTED: Delete image
       func deleteImage(at path: String) async throws {
           // Removes from Firebase Storage
       }
   }
   ```

2. ⚠️ **TODO:** Add progress tracking overload for message attachments:
   ```swift
   extension StorageService {
       /// Upload image with progress tracking for message attachments
       func uploadImage(
           _ image: UIImage,
           conversationID: String,
           messageID: String,
           onProgress: @escaping (Double) -> Void
       ) async throws -> String {
           // Compress image
           let compressedImage = compressImage(image)

           guard let imageData = compressedImage.jpegData(compressionQuality: compressionQuality) else {
               throw StorageError.compressionFailed
           }

           // Create storage reference
           let filename = UUID().uuidString + ".jpg"
           let ref = storage.reference()
               .child("conversations")
               .child(conversationID)
               .child("images")
               .child(filename)

           // Upload with progress tracking
           let metadata = StorageMetadata()
           metadata.contentType = "image/jpeg"

           return try await withCheckedThrowingContinuation { continuation in
               let uploadTask = ref.putData(imageData, metadata: metadata)

               uploadTask.observe(.progress) { snapshot in
                   guard let progress = snapshot.progress else { return }
                   let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                   onProgress(percentComplete)
               }

               uploadTask.observe(.success) { _ in
                   ref.downloadURL { url, error in
                       if let error = error {
                           continuation.resume(throwing: error)
                       } else if let url = url {
                           continuation.resume(returning: url.absoluteString)
                       }
                   }
               }

               uploadTask.observe(.failure) { snapshot in
                   if let error = snapshot.error {
                       continuation.resume(throwing: error)
                   }
               }
           }
       }

       private func compressImage(_ image: UIImage) -> UIImage {
           let size = image.size
           let ratio = max(size.width, size.height) / maxImageDimension

           if ratio > 1 {
               let newSize = CGSize(
                   width: size.width / ratio,
                   height: size.height / ratio
               )

               UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
               image.draw(in: CGRect(origin: .zero, size: newSize))
               let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
               UIGraphicsEndImageContext()

               return resizedImage ?? image
           }

           return image
       }

       func uploadGroupPhoto(_ image: UIImage, groupID: String) async throws -> String {
           let compressedImage = compressImage(image)

           guard let imageData = compressedImage.jpegData(compressionQuality: compressionQuality) else {
               throw StorageError.compressionFailed
           }

           let filename = "group_photo.jpg"
           let ref = storage.reference()
               .child("groups")
               .child(groupID)
               .child(filename)

           let metadata = StorageMetadata()
           metadata.contentType = "image/jpeg"

           _ = try await ref.putDataAsync(imageData, metadata: metadata)
           let url = try await ref.downloadURL()

           return url.absoluteString
       }
   }

   enum StorageError: Error {
       case compressionFailed
       case uploadFailed
   }
   ```

3. ⚠️ **TODO:** Update MessageThreadViewModel to handle image uploads:
   ```swift
   @MainActor
   final class MessageThreadViewModel: ObservableObject {
       // ... existing properties ...
       @Published var uploadProgress: [String: Double] = [:] // attachmentID -> progress

       func sendMessage(text: String, images: [UIImage]) async {
           let message = MessageEntity(
               id: UUID().uuidString,
               conversationID: conversationID,
               senderID: AuthService.shared.currentUserID,
               text: text,
               createdAt: Date(),
               status: .sent,
               syncStatus: .pending,
               attachments: []
           )

           // Save message locally first
           modelContext.insert(message)
           try? modelContext.save()

           // Upload images in parallel (max 3 concurrent)
           await withTaskGroup(of: AttachmentEntity?.self) { group in
               for image in images {
                   group.addTask {
                       let attachmentID = UUID().uuidString

                       do {
                           let url = try await StorageService.shared.uploadImage(
                               image,
                               conversationID: self.conversationID,
                               messageID: message.id
                           ) { progress in
                               Task { @MainActor in
                                   self.uploadProgress[attachmentID] = progress
                               }
                           }

                           let attachment = AttachmentEntity(
                               id: attachmentID,
                               messageID: message.id,
                               type: .image,
                               url: url,
                               thumbnailURL: url,
                               fileName: nil,
                               fileSize: nil,
                               mimeType: "image/jpeg",
                               width: Int(image.size.width),
                               height: Int(image.size.height),
                               createdAt: Date()
                           )

                           return attachment
                       } catch {
                           print("Failed to upload image: \(error)")
                           return nil
                       }
                   }
               }

               for await attachment in group {
                   if let attachment = attachment {
                       message.attachments.append(attachment)
                       try? modelContext.save()
                   }
               }
           }

           // Sync message to Firestore
           message.syncStatus = .synced
           try? modelContext.save()

           Task.detached {
               try? await MessageService.shared.syncMessage(message)
           }
       }
   }
   ```

4. ⚠️ **TODO:** Update MessageBubbleView to show upload progress:
   - Show circular progress indicator with percentage
   - Display uploading state with `AttachmentEntity.uploadProgress`
   - Show retry button if `uploadStatus == .failed`

5. ⚠️ **TODO:** Add retry button for failed uploads:
   - Check `AttachmentEntity.uploadError` for error message
   - Show red "!" badge on failed attachments
   - Tap to retry upload

**iOS Mobile Considerations:**
- **Upload Progress:**
  - Show circular progress indicator overlay on image thumbnail
  - Display percentage: "47%" in center of circle
  - Use `ProgressView(value: progress)` with `.progressViewStyle(.circular)`
- **Image Compression:**
  - Compress on background thread to avoid blocking main thread
  - Show "Compressing..." state before upload starts
  - Target: < 500KB per image for mobile data savings
- **Parallel Uploads:**
  - Limit to 3 concurrent uploads to avoid overwhelming device/network
  - Use `TaskGroup` for structured concurrency
- **Upload Cancellation:**
  - Allow user to cancel upload mid-progress
  - Show "Cancel" button on uploading images
- **Error Handling:**
  - Show red "!" badge on failed uploads
  - Tap failed image to retry
  - Use haptic error feedback on failure
- **Cellular Data Warning:**
  - Optional: Warn user if uploading large images on cellular (not Wi-Fi)
  - Use `NWPathMonitor` to detect connection type

**References:**
- Architecture Doc Section 8.2 (Firebase Storage)

---

### Story 4.3: Image Caching with Kingfisher
**As a user, I want images to load quickly so I don't waste bandwidth re-downloading.**

**Acceptance Criteria:**
- [ ] Images cached locally after first download
- [ ] Cached images load instantly on subsequent views
- [ ] Cache size limited to 500MB
- [ ] Old cache entries cleared automatically (LRU)
- [ ] Placeholder shown while loading
- [ ] Failed image loads show broken image icon

**Technical Tasks:**

> **✅ IMPLEMENTATION NOTE:** Kingfisher already configured and used in multiple views
> **Status:** Caching works, but need consistent usage across all views

1. ✅ **DONE:** Kingfisher configured in AppContainer and used in ProfileView:
   - Cache limits already set (likely in AppContainer initialization)
   - Kingfisher used in ProfileView for profile pictures
   - `KFImage` provides automatic caching

2. ⚠️ **TODO:** Configure explicit cache limits (if not already done):
   ```swift
   import Kingfisher

   @main
   struct SortedApp: App {
       init() {
           FirebaseApp.configure()

           // Configure Kingfisher cache
           let cache = ImageCache.default
           cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100MB memory
           cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500MB disk
           cache.diskStorage.config.expiration = .days(7) // 7 days
       }
   }
   ```

3. ⚠️ **OPTION A - TODO:** Create CachedAsyncImage wrapper for API consistency:
   ```swift
   import Kingfisher

   struct CachedAsyncImage<Content: View, Placeholder: View>: View {
       let url: URL?
       let content: (Image) -> Content
       let placeholder: () -> Placeholder

       init(
           url: URL?,
           @ViewBuilder content: @escaping (Image) -> Content,
           @ViewBuilder placeholder: @escaping () -> Placeholder
       ) {
           self.url = url
           self.content = content
           self.placeholder = placeholder
       }

       var body: some View {
           KFImage(url)
               .placeholder {
                   placeholder()
               }
               .cacheMemoryOnly()
               .fade(duration: 0.25)
               .onSuccess { result in
                   print("Image loaded: \(result.cacheType)")
               }
               .onFailure { error in
                   print("Image load failed: \(error)")
               }
               .resizable()
       }
   }

   // Convenience init for default placeholder
   extension CachedAsyncImage where Placeholder == Color {
       init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
           self.url = url
           self.content = content
           self.placeholder = { Color.gray.opacity(0.2) }
       }
   }
   ```

   **OPTION B - TODO (SIMPLER):** Use `KFImage` directly everywhere:
   ```swift
   import Kingfisher

   // Replace AsyncImage with KFImage throughout codebase
   KFImage(url)
       .placeholder { ProgressView() }
       .retry(maxCount: 3, interval: .seconds(1))
       .onSuccess { result in
           print("Cached: \(result.cacheType)")
       }
       .resizable()
       .scaledToFill()
   ```

4. ⚠️ **TODO:** Update MessageBubbleView to use cached images:
   ```swift
   struct MessageBubbleView: View {
       let message: MessageEntity

       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               // Image attachments
               if !message.attachments.isEmpty {
                   LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                       ForEach(message.attachments) { attachment in
                           if attachment.type == .image {
                               CachedAsyncImage(url: URL(string: attachment.url)) { image in
                                   image
                                       .scaledToFill()
                                       .frame(width: 150, height: 150)
                                       .clipShape(RoundedRectangle(cornerRadius: 8))
                                       .onTapGesture {
                                           showMediaViewer(attachment: attachment)
                                       }
                               } placeholder: {
                                   RoundedRectangle(cornerRadius: 8)
                                       .fill(Color.gray.opacity(0.2))
                                       .frame(width: 150, height: 150)
                                       .overlay {
                                           ProgressView()
                                       }
                               }
                           }
                       }
                   }
               }

               // Text message
               if !message.text.isEmpty {
                   Text(message.text)
                       .padding(.horizontal, 16)
                       .padding(.vertical, 10)
                       .background(
                           isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2)
                       )
                       .foregroundColor(isFromCurrentUser ? .white : .primary)
                       .cornerRadius(18)
               }
           }
       }
   }
   ```

5. ✅ **DONE:** Kingfisher added to SPM dependencies in Epic 0

6. ⚠️ **ACTION REQUIRED:** Replace all `AsyncImage` with `KFImage`:
   - EditGroupInfoView.swift line 87 (group photo)
   - Any other views using `AsyncImage` for remote images

**References:**
- Kingfisher Documentation: https://github.com/onevcat/Kingfisher

---

### Story 4.4: Full-Screen Media Viewer
**As a user, I want to view images in full-screen so I can see details clearly.**

> **❌ IMPLEMENTATION STATUS:** Not started - Critical UX component missing
> **Priority:** P0 (High) - Essential for good user experience
> **Blocking:** Story 4.1 image display in messages

**Acceptance Criteria:**
- [ ] Tap image in chat opens full-screen viewer
- [ ] Viewer supports pinch-to-zoom gestures
- [ ] Viewer supports pan gestures when zoomed
- [ ] Swipe down to dismiss (interactive dismissal)
- [ ] Multiple images show with horizontal paging
- [ ] Share button to share image via iOS share sheet
- [ ] Download button to save image to Photos library

**Technical Tasks:**

> **⚠️ CRITICAL:** This entire story needs implementation from scratch

1. ⚠️ **TODO:** Create MediaViewerView component:
   ```swift
   struct MediaViewerView: View {
       let attachments: [AttachmentEntity]
       let initialIndex: Int

       @Environment(\.dismiss) private var dismiss
       @State private var currentIndex: Int
       @State private var scale: CGFloat = 1.0
       @State private var offset: CGSize = .zero
       @State private var showControls = true

       init(attachments: [AttachmentEntity], initialIndex: Int) {
           self.attachments = attachments
           self.initialIndex = initialIndex
           _currentIndex = State(initialValue: initialIndex)
       }

       var body: some View {
           ZStack {
               Color.black.ignoresSafeArea()

               TabView(selection: $currentIndex) {
                   ForEach(attachments.indices, id: \.self) { index in
                       GeometryReader { geometry in
                           CachedAsyncImage(url: URL(string: attachments[index].url)) { image in
                               image
                                   .scaledToFit()
                                   .scaleEffect(scale)
                                   .offset(offset)
                                   .gesture(
                                       MagnificationGesture()
                                           .onChanged { value in
                                               scale = max(1.0, min(value, 4.0))
                                           }
                                           .onEnded { _ in
                                               withAnimation {
                                                   if scale < 1.5 {
                                                       scale = 1.0
                                                       offset = .zero
                                                   }
                                               }
                                           }
                                   )
                                   .gesture(
                                       DragGesture()
                                           .onChanged { value in
                                               if scale > 1.0 {
                                                   offset = value.translation
                                               }
                                           }
                                           .onEnded { _ in
                                               withAnimation {
                                                   // Dismiss if swiping down when not zoomed
                                                   if scale == 1.0 && offset.height > 100 {
                                                       dismiss()
                                                   } else if scale == 1.0 {
                                                       offset = .zero
                                                   }
                                               }
                                           }
                                   )
                                   .onTapGesture {
                                       withAnimation {
                                           showControls.toggle()
                                       }
                                   }
                           }
                       }
                       .tag(index)
                   }
               }
               .tabViewStyle(.page(indexDisplayMode: .never))

               // Top controls
               if showControls {
                   VStack {
                       HStack {
                           Button {
                               dismiss()
                           } label: {
                               Image(systemName: "xmark")
                                   .font(.system(size: 20, weight: .semibold))
                                   .foregroundColor(.white)
                                   .padding(12)
                                   .background(Circle().fill(Color.black.opacity(0.5)))
                           }

                           Spacer()

                           Text("\(currentIndex + 1) of \(attachments.count)")
                               .font(.system(size: 16, weight: .medium))
                               .foregroundColor(.white)

                           Spacer()

                           Menu {
                               Button {
                                   shareImage()
                               } label: {
                                   Label("Share", systemImage: "square.and.arrow.up")
                               }

                               Button {
                                   Task { await downloadImage() }
                               } label: {
                                   Label("Save to Photos", systemImage: "square.and.arrow.down")
                               }
                           } label: {
                               Image(systemName: "ellipsis")
                                   .font(.system(size: 20, weight: .semibold))
                                   .foregroundColor(.white)
                                   .padding(12)
                                   .background(Circle().fill(Color.black.opacity(0.5)))
                           }
                       }
                       .padding()

                       Spacer()
                   }
                   .transition(.opacity)
               }
           }
       }

       private func shareImage() {
           // TODO: Implement share sheet
       }

       private func downloadImage() async {
           // TODO: Implement save to Photos library
       }
   }
   ```

2. ⚠️ **TODO:** Add gesture recognizers for zoom and pan:
   - `MagnificationGesture()` for pinch-to-zoom (1x - 4x)
   - `DragGesture()` for pan when zoomed
   - Double-tap to toggle zoom (1x ↔ 2x)

3. ⚠️ **TODO:** Implement share sheet integration:
   ```swift
   // Wrap UIActivityViewController in UIViewControllerRepresentable
   struct ShareSheet: UIViewControllerRepresentable {
       let items: [Any]
       // ... implementation
   }
   ```

4. ⚠️ **TODO:** Implement save to Photos library:
   ```swift
   import Photos

   func saveToPhotos(_ image: UIImage) async throws {
       try await PHPhotoLibrary.shared().performChanges {
           PHAssetChangeRequest.creationRequestForAsset(from: image)
       }
   }
   ```
   - Request `NSPhotoLibraryAddUsageDescription` permission
   - Show success/error alerts

**iOS Mobile Considerations:**
- **Pinch-to-Zoom Gestures:**
  - Use `MagnificationGesture()` for zoom (min 1.0x, max 4.0x)
  - Combine with `DragGesture()` for pan when zoomed
  - Double-tap to zoom in/out (toggle between 1x and 2x)
- **Swipe-to-Dismiss:**
  - Swipe down when at 1x zoom to dismiss viewer
  - Use `.offset()` and animation for interactive dismissal
  - Prevent dismiss when zoomed (> 1.0x)
- **Horizontal Paging:**
  - Use `TabView(selection:)` with `.tabViewStyle(.page)` for swiping between images
  - Show image counter: "2 of 5" in top overlay
- **Share Sheet:**
  - Use `UIActivityViewController` wrapped in `UIViewControllerRepresentable`
  - Share original image URL, not thumbnail
- **Save to Photos:**
  - Request photo library add permission (different from read permission!)
  - Use `PHPhotoLibrary.shared().performChanges()` for saving
  - Show success alert with haptic feedback
- **Accessibility:**
  - VoiceOver describes current image and position
  - Zoom level announced when changed
  - Actions (share, save) properly labeled

**References:**
- UX Design Doc Section 3.4 (Media Viewer)

---

### Story 4.5: Video Sharing
**As a user, I want to share videos so I can send multimedia content.**

> **❌ IMPLEMENTATION STATUS:** Not started - Video upload and playback missing
> **Priority:** P2 (Medium) - Nice-to-have for MVP, can ship with images first
> **Dependencies:** Story 4.2 (upload infrastructure), AttachmentEntity enhancements

**Acceptance Criteria:**
- [ ] User can select videos from PHPicker
- [ ] Videos limited to 100MB file size
- [ ] Videos show thumbnail in chat thread
- [ ] Tap video thumbnail opens full-screen player
- [ ] Upload progress shown during upload
- [ ] Videos play inline with controls (play/pause, scrubber)

**Technical Tasks:**

> **⚠️ BLOCKERS:**
> - AttachmentEntity needs `duration` property (Story 4.1)
> - StorageService needs video upload method
> - VideoPlayerView component doesn't exist

1. ⚠️ **TODO:** Update AttachmentEntity to support video metadata:
   ```swift
   @Model
   final class AttachmentEntity {
       @Attribute(.unique) var id: String
       var messageID: String
       var type: AttachmentType // .image, .video, .file
       var url: String
       var thumbnailURL: String?
       var fileName: String?
       var fileSize: Int?
       var mimeType: String
       var width: Int?
       var height: Int?
       var duration: TimeInterval? // For videos
       var createdAt: Date
   }

   enum AttachmentType: String, Codable {
       case image
       case video
       case file
   }
   ```

2. ⚠️ **TODO:** Add video upload to StorageService:
   ```swift
   extension StorageService {
       func uploadVideo(
           _ videoURL: URL,
           conversationID: String,
           messageID: String,
           onProgress: @escaping (Double) -> Void
       ) async throws -> (videoURL: String, thumbnailURL: String) {
           // Check file size
           let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int ?? 0
           let maxSize = 100 * 1024 * 1024 // 100MB

           guard fileSize <= maxSize else {
               throw StorageError.fileTooLarge
           }

           // Generate thumbnail
           let thumbnail = try await generateVideoThumbnail(from: videoURL)

           // Upload thumbnail
           let thumbnailURL = try await uploadImage(
               thumbnail,
               conversationID: conversationID,
               messageID: messageID,
               onProgress: { _ in }
           )

           // Upload video
           let filename = UUID().uuidString + ".mp4"
           let ref = storage.reference()
               .child("conversations")
               .child(conversationID)
               .child("videos")
               .child(filename)

           let metadata = StorageMetadata()
           metadata.contentType = "video/mp4"

           let videoData = try Data(contentsOf: videoURL)

           let videoURLString = try await withCheckedThrowingContinuation { continuation in
               let uploadTask = ref.putData(videoData, metadata: metadata)

               uploadTask.observe(.progress) { snapshot in
                   guard let progress = snapshot.progress else { return }
                   let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                   onProgress(percentComplete)
               }

               uploadTask.observe(.success) { _ in
                   ref.downloadURL { url, error in
                       if let error = error {
                           continuation.resume(throwing: error)
                       } else if let url = url {
                           continuation.resume(returning: url.absoluteString)
                       }
                   }
               }

               uploadTask.observe(.failure) { snapshot in
                   if let error = snapshot.error {
                       continuation.resume(throwing: error)
                   }
               }
           }

           return (videoURLString, thumbnailURL)
       }

       private func generateVideoThumbnail(from url: URL) async throws -> UIImage {
           let asset = AVAsset(url: url)
           let imageGenerator = AVAssetImageGenerator(asset: asset)
           imageGenerator.appliesPreferredTrackTransform = true

           let time = CMTime(seconds: 1, preferredTimescale: 60)
           let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)

           return UIImage(cgImage: cgImage)
       }
   }

   extension StorageError {
       case fileTooLarge
   }
   ```

3. ⚠️ **TODO:** Create VideoPlayerView for inline playback:
   ```swift
   import AVKit

   struct VideoPlayerView: View {
       let url: URL

       var body: some View {
           VideoPlayer(player: AVPlayer(url: url))
               .frame(height: 300)
               .cornerRadius(12)
       }
   }
   ```

4. ⚠️ **TODO:** Update MessageBubbleView to render video attachments:
   - Show video thumbnail with play button overlay
   - Tap to open VideoPlayerView or MediaViewerView
   - Display duration badge (e.g., "1:23")

**References:**
- PRD Epic 4: Media Sharing (Videos)

---

### Story 4.6: File Sharing (PDFs, Documents)
**As a user, I want to share files so I can send documents and PDFs.**

> **❌ IMPLEMENTATION STATUS:** Not started - Lower priority feature
> **Priority:** P3 (Low) - Consider moving to Epic 5 or Phase 2
> **Recommendation:** Ship MVP with images first, add files later

**Acceptance Criteria:**
- [ ] User can select files via document picker
- [ ] Supported types: PDF, DOC, DOCX, TXT, XLS, XLSX
- [ ] Files limited to 50MB file size
- [ ] Files show with file icon and name in chat
- [ ] Tap file downloads and opens in system viewer
- [ ] Download progress shown during download

**Technical Tasks:**

> **💡 STRATEGIC NOTE:** Consider deferring this story to focus on core image/video sharing first

1. ⚠️ **TODO:** Create DocumentPicker wrapper (UIKit):
   ```swift
   import UniformTypeIdentifiers

   struct DocumentPicker: UIViewControllerRepresentable {
       @Binding var fileURL: URL?

       func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
           let picker = UIDocumentPickerViewController(
               forOpeningContentTypes: [
                   .pdf,
                   .plainText,
                   UTType(filenameExtension: "doc")!,
                   UTType(filenameExtension: "docx")!,
                   UTType(filenameExtension: "xls")!,
                   UTType(filenameExtension: "xlsx")!
               ]
           )
           picker.delegate = context.coordinator
           return picker
       }

       func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

       func makeCoordinator() -> Coordinator {
           Coordinator(self)
       }

       class Coordinator: NSObject, UIDocumentPickerDelegate {
           let parent: DocumentPicker

           init(_ parent: DocumentPicker) {
               self.parent = parent
           }

           func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
               parent.fileURL = urls.first
           }
       }
   }
   ```

2. ⚠️ **TODO:** Add file upload to StorageService:
   ```swift
   extension StorageService {
       func uploadFile(
           _ fileURL: URL,
           conversationID: String,
           messageID: String,
           onProgress: @escaping (Double) -> Void
       ) async throws -> String {
           // Similar to uploadVideo, but for documents
           // Enforce 50MB limit
       }
   }
   ```

3. ⚠️ **TODO:** Create FileAttachmentView component:
   ```swift
   struct FileAttachmentView: View {
       let attachment: AttachmentEntity

       var body: some View {
           HStack {
               Image(systemName: fileIcon(for: attachment.mimeType))
               VStack(alignment: .leading) {
                   Text(attachment.fileName)
                   Text(formatFileSize(attachment.fileSize))
                       .font(.caption)
               }
           }
       }
   }
   ```

4. ⚠️ **TODO:** Implement file download and open in system viewer:
   - Download file to temp directory
   - Use `UIDocumentInteractionController` to open
   - Show download progress

**References:**
- Architecture Doc Section 8.2 (File Sharing)

---

## Dependencies & Prerequisites

### ✅ Already Complete:
- [x] Epic 0: Project Scaffolding (Firebase Storage configured)
- [x] Epic 2: One-on-One Chat (MessageEntity with attachments relationship)
- [x] AttachmentEntity model created with upload tracking
- [x] StorageService basic implementation (image upload, compression)
- [x] Kingfisher 7.10+ (image caching) - SPM dependency added
- [x] Firebase Storage SDK - Configured and working
- [x] ImagePicker and PhotosPicker components
- [x] Info.plist permissions (Camera, Photo Library)

### 🚧 Ready to Integrate (Models Exist, Need UI):
- MessageComposerView attachment support
- MessageBubbleView attachment display
- Upload progress UI
- Image caching in message views

### ⚠️ Not Yet Implemented:
- CameraView wrapper
- MediaViewerView (full-screen viewer)
- Video upload and playback
- File/document sharing

---

## Testing & Verification

### Verification Checklist:
- [ ] Images upload and display in chat
- [ ] Upload progress shows correctly
- [ ] Images cached after first load
- [ ] Full-screen viewer works with zoom/pan
- [ ] Videos upload with thumbnails
- [ ] Files upload and download correctly
- [ ] Offline uploads queue and retry

---

## Success Criteria

### MVP Success Criteria (Image Sharing Only):
**Epic 4 MVP is complete when:**
- ✅ Users can share images from photos and camera
- ✅ Images upload with progress indicators
- ✅ Images cached with Kingfisher (no redundant downloads)
- ✅ Full-screen media viewer with zoom/pan/share works
- ✅ Images display correctly in message threads
- ✅ Upload failures show retry button

### Full Epic Success Criteria (Complete):
**Epic 4 is fully complete when:**
- ✅ All MVP criteria met
- ✅ Videos upload with thumbnail generation
- ✅ Videos play inline with controls
- ✅ Files (PDF, DOC) upload and download
- ✅ Offline upload queue and sync
- ✅ Save to Photos library works

### Current Status:
- 🟡 **Foundation Complete** (~35%): Models, services, pickers exist
- 🟡 **MVP In Progress** (~40% remaining): Need UI integration
- ❌ **Extended Features Not Started**: Video/file sharing

---

## Time Estimates

### Original Estimates vs Actual Progress

| Story | Original Estimate | Already Complete | Remaining Work | Revised Estimate |
|-------|------------------|------------------|----------------|------------------|
| 4.1 Image Picker and Camera | 60 min | ~40% (models, pickers) | CameraView, MessageComposer integration | **35 min** |
| 4.2 Firebase Storage Upload | 75 min | ~60% (basic upload, compression) | Progress callbacks, parallel uploads, retry UI | **30 min** |
| 4.3 Kingfisher Image Caching | 30 min | ~70% (configured, used in some views) | CachedAsyncImage wrapper, replace AsyncImage | **15 min** |
| 4.4 Full-Screen Media Viewer | 60 min | 0% (not started) | Entire story | **90 min** ⚠️ |
| 4.5 Video Sharing | 60 min | 0% (not started) | Entire story | **90 min** |
| 4.6 File Sharing | 45 min | 0% (not started) | Entire story | **60 min** |
| **Original Total** | **4-5 hours** | **~35% done** | - | - |
| **Remaining (MVP)** | - | - | Stories 4.1-4.4 | **2.5 hours** |
| **Remaining (Full)** | - | - | All stories | **5 hours** |

### Recommended MVP Scope (2.5 hours):
1. ✅ Story 4.1: Complete MessageComposer integration (35 min)
2. ✅ Story 4.2: Add progress tracking UI (30 min)
3. ✅ Story 4.3: Standardize on KFImage (15 min)
4. ✅ Story 4.4: Implement MediaViewerView (90 min)

**MVP Result:** Users can send/receive/view images with progress tracking and full-screen viewer.

### Optional Extended Scope (+2.5 hours):
5. ⏳ Story 4.5: Video sharing (90 min)
6. ⏳ Story 4.6: File sharing (60 min)

---

## Implementation Order

**Recommended sequence:**
1. Story 4.1 (Image Picker) - Foundation
2. Story 4.2 (Storage Upload) - Core functionality
3. Story 4.3 (Kingfisher Caching) - Performance
4. Story 4.4 (Media Viewer) - User experience
5. Story 4.5 (Video Sharing) - Extended media
6. Story 4.6 (File Sharing) - Documents

---

## References

- **SwiftData Implementation Guide**: `docs/swiftdata-implementation-guide.md` (Section 3.4: AttachmentEntity)
- **Architecture Doc**: `docs/architecture.md` (Section 8.2: Firebase Storage)
- **PRD**: `docs/prd.md` (Epic 4: Media Sharing)

---

## 📊 Epic Status Summary

**Epic Status:** 🟡 **In Progress** (~35% Foundation Complete)
**Last Updated:** 2025-10-22
**Blockers:** None - Ready for UI integration
**Risk Level:** Medium (Storage quota management, video complexity)

### What's Working:
- ✅ AttachmentEntity SwiftData model with upload tracking
- ✅ StorageService with image upload and compression
- ✅ ImagePicker and PhotosPicker components
- ✅ Kingfisher caching configured
- ✅ Group photo upload working (GroupCreationView)
- ✅ Profile picture upload working (ProfileView)

### Critical Path to MVP (2.5 hours):
1. **Story 4.1** (35 min): CameraView + MessageComposer attachment UI
2. **Story 4.2** (30 min): Progress tracking callbacks + retry UI
3. **Story 4.3** (15 min): Replace AsyncImage with KFImage everywhere
4. **Story 4.4** (90 min): MediaViewerView with zoom/pan/share

### Nice-to-Have (Defer to Phase 2):
- Story 4.5: Video sharing (90 min)
- Story 4.6: File sharing (60 min)

### Key Decisions Needed:
1. **Ship MVP with images only?** (Recommended: YES ✅)
   - Faster time-to-market
   - Video/files add complexity
   - Can iterate in Phase 2

2. **Use CachedAsyncImage wrapper or KFImage directly?** (Recommended: KFImage ✅)
   - Simpler implementation
   - Better performance
   - Less code to maintain

3. **Priority of MediaViewerView?** (Recommended: P0 - Critical for UX ✅)
   - Essential for good image viewing experience
   - Users expect zoom/pan in modern apps
   - Differentiator from basic chat apps

---

**Epic Dependencies:** Epic 0 ✅, Epic 2 ✅
**Sprint Recommendation:** Complete Stories 4.1-4.4 in current sprint (MVP), defer 4.5-4.6
