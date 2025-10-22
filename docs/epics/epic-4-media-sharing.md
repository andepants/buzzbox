# Epic 4: Media Sharing (Images, Videos, Files)

**Phase:** Day 2-3 (Extended Messaging)
**Priority:** P1 (High - Core Feature)
**Estimated Time:** 4-5 hours
**Epic Owner:** Development Team Lead
**Dependencies:** Epic 2 (One-on-One Chat), Epic 3 (Group Chat)

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
1. Update MessageEntity to support attachments (already defined in SwiftData guide):
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
       @Relationship(deleteRule: .cascade) var attachments: [AttachmentEntity]
       var isSystemMessage: Bool
       var readBy: [String: Date]

       // ... initializer ...
   }
   ```

2. Create AttachmentPickerView:
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

3. Create CameraView wrapper (UIKit):
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

4. Update MessageComposerView to show attachment menu:
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

5. Request camera permission in Info.plist (already done in Epic 0)

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
1. Create StorageService for Firebase Storage operations:
   ```swift
   import FirebaseStorage

   final class StorageService {
       static let shared = StorageService()

       private let storage = Storage.storage()
       private let compressionQuality: CGFloat = 0.85
       private let maxImageDimension: CGFloat = 2048

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

2. Update MessageThreadViewModel to handle image uploads:
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

3. Update MessageBubbleView to show upload progress
4. Add retry button for failed uploads

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
1. Configure Kingfisher in SortedApp.swift:
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

2. Create CachedAsyncImage wrapper:
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

3. Update MessageBubbleView to use CachedAsyncImage:
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

4. Add Kingfisher to SPM dependencies (already done in Epic 0)

**References:**
- Kingfisher Documentation: https://github.com/onevcat/Kingfisher

---

### Story 4.4: Full-Screen Media Viewer
**As a user, I want to view images in full-screen so I can see details clearly.**

**Acceptance Criteria:**
- [ ] Tap image in chat opens full-screen viewer
- [ ] Viewer supports pinch-to-zoom gestures
- [ ] Viewer supports pan gestures when zoomed
- [ ] Swipe down to dismiss (interactive dismissal)
- [ ] Multiple images show with horizontal paging
- [ ] Share button to share image via iOS share sheet
- [ ] Download button to save image to Photos library

**Technical Tasks:**
1. Create MediaViewerView:
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

2. Add gesture recognizers for zoom and pan
3. Implement share sheet integration
4. Implement save to Photos library (requires permission)

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

**Acceptance Criteria:**
- [ ] User can select videos from PHPicker
- [ ] Videos limited to 100MB file size
- [ ] Videos show thumbnail in chat thread
- [ ] Tap video thumbnail opens full-screen player
- [ ] Upload progress shown during upload
- [ ] Videos play inline with controls (play/pause, scrubber)

**Technical Tasks:**
1. Update AttachmentEntity to support videos:
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

2. Add video upload to StorageService:
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

3. Create VideoPlayerView for inline playback
4. Update MessageBubbleView to render video attachments

**References:**
- PRD Epic 4: Media Sharing (Videos)

---

### Story 4.6: File Sharing (PDFs, Documents)
**As a user, I want to share files so I can send documents and PDFs.**

**Acceptance Criteria:**
- [ ] User can select files via document picker
- [ ] Supported types: PDF, DOC, DOCX, TXT, XLS, XLSX
- [ ] Files limited to 50MB file size
- [ ] Files show with file icon and name in chat
- [ ] Tap file downloads and opens in system viewer
- [ ] Download progress shown during download

**Technical Tasks:**
1. Create DocumentPicker wrapper (UIKit):
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

2. Add file upload to StorageService
3. Create FileAttachmentView component
4. Implement file download and open in system viewer

**References:**
- Architecture Doc Section 8.2 (File Sharing)

---

## Dependencies & Prerequisites

### Required Epics:
- [x] Epic 0: Project Scaffolding (Firebase Storage configured)
- [x] Epic 2: One-on-One Chat (Message infrastructure)

### Required Packages:
- [x] Kingfisher 7.10+ (image caching)
- [x] Firebase Storage SDK

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

**Epic 4 is complete when:**
- ✅ Users can share images from photos and camera
- ✅ Images upload with progress indicators
- ✅ Images cached with Kingfisher
- ✅ Full-screen media viewer works
- ✅ Videos upload with thumbnails
- ✅ Files upload and download
- ✅ Offline uploads queue and sync

---

## Time Estimates

| Story | Estimated Time |
|-------|---------------|
| 4.1 Image Picker and Camera | 60 mins |
| 4.2 Firebase Storage Upload | 75 mins |
| 4.3 Kingfisher Image Caching | 30 mins |
| 4.4 Full-Screen Media Viewer | 60 mins |
| 4.5 Video Sharing | 60 mins |
| 4.6 File Sharing | 45 mins |
| **Total** | **4-5 hours** |

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

**Epic Status:** Ready for implementation
**Blockers:** None (depends on Epic 2)
**Risk Level:** Medium (Storage quota management)
