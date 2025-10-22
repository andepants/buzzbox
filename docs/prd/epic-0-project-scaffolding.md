# Epic 0: Project Scaffolding & Development Environment Setup

**Phase:** Pre-MVP (Day 0 - Setup)
**Priority:** P0 (Blocker - Must complete before Day 1)
**Estimated Time:** 2-4 hours
**Epic Owner:** Development Team Lead

---

## Overview

Set up the complete iOS development environment, Xcode project structure, Firebase backend, and all required dependencies before beginning Day 1 MVP development. This epic ensures a solid foundation for rapid development with no blockers during the 7-day sprint.

---

## What This Epic Delivers

- ✅ Xcode project initialized with Swift 6 + iOS 17+ configuration
- ✅ SwiftData schema and ModelContainer configured
- ✅ Firebase project created and integrated (Auth, Firestore, Storage, Functions, FCM)
- ✅ All SPM dependencies installed and verified
- ✅ Development environment running on simulator
- ✅ Project file structure following AI-first architecture principles
- ✅ Initial .gitignore, README, and basic documentation

---

### iOS-Specific Mobile Setup Notes

**This is a native iOS mobile app** - ensure all scaffolding follows iOS best practices:

- ✅ **Info.plist Permissions:** Camera, Photo Library, Notifications (NSCameraUsageDescription, NSPhotoLibraryUsageDescription, etc.)
- ✅ **Build Configurations:** Development (emulators), Staging, Production with proper bundle IDs
- ✅ **Swift 6 Strict Concurrency:** Enable `SWIFT_STRICT_CONCURRENCY = complete` for compile-time safety
- ✅ **iOS Deployment Target:** Set to iOS 17.0 minimum (SwiftData requirement)
- ✅ **Simulator Testing:** Test on iPhone SE (small screen), iPhone 14 Pro (Dynamic Island), iPad
- ✅ **Keychain Entitlements:** Configure for secure token storage
- ✅ **Background Modes:** Enable if needed for notifications, background fetch
- ✅ **App Icons & Launch Screen:** Set up iOS-specific assets

---

## User Stories

### Story 0.1: Initialize Xcode Project
**As a developer, I need a properly configured Xcode project so I can begin iOS development immediately.**

**Acceptance Criteria:**
- [ ] New Xcode project created: "Sorted"
- [ ] Bundle ID: `com.sorted.app.dev`
- [ ] iOS Deployment Target: iOS 17.0
- [ ] Language: Swift 6
- [ ] UI Framework: SwiftUI
- [ ] Swift Concurrency enabled (strict mode)
- [ ] Project builds and runs on simulator without errors

**Technical Tasks:**
1. Create new Xcode project (iOS App template)
2. Configure project settings:
   - Enable Swift 6 strict concurrency checking
   - Set minimum deployment target to iOS 17.0
   - Configure build settings for Debug/Release
3. Set up build configurations:
   - Development (Firebase Emulators)
   - Staging (Firebase staging project)
   - Production (Firebase production project)
4. Configure Info.plist with required keys:
   - Camera usage description (for profile pictures)
   - Photo library usage description
   - Notifications usage description

**iOS Mobile Considerations:**
- **Info.plist Required Keys** (add these NOW to avoid permission crashes later):
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>We need camera access to take profile pictures and share photos in messages.</string>

  <key>NSPhotoLibraryUsageDescription</key>
  <string>We need access to your photos to set profile pictures and share images.</string>

  <key>NSUserNotificationsUsageDescription</key>
  <string>We'll send you notifications for new messages so you never miss a conversation.</string>
  ```
- **Simulator vs Device Testing:** Simulator can't test camera, push notifications, or some Keychain features - plan for device testing
- **Bundle ID Convention:** Use reverse domain notation (com.sorted.app.dev for development)

---

### Story 0.2: Install Swift Package Manager Dependencies
**As a developer, I need all required libraries installed so I can use them during development.**

**Acceptance Criteria:**
- [ ] Firebase iOS SDK 10.20+ installed (Auth, Firestore, Messaging, Storage)
- [ ] Kingfisher 7.10+ installed (image caching)
- [ ] All packages resolve without conflicts
- [ ] Project builds successfully with all dependencies

**Technical Tasks:**
1. Add Firebase iOS SDK via SPM:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseMessaging
   - FirebaseStorage
   - FirebaseAnalytics
   - FirebaseCrashlytics
2. Add supporting libraries:
   - Kingfisher (image loading/caching)
3. Verify package resolution
4. Test build with all dependencies

**Package Versions:**
```swift
// Package.swift dependencies
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.20.0"),
.package(url: "https://github.com/onevcat/Kingfisher", from: "7.10.0")
```

---

### Story 0.3: Set Up Firebase Backend
**As a developer, I need Firebase configured so I can use Auth, Firestore, Storage, and Cloud Functions.**

**Acceptance Criteria:**
- [ ] Firebase project created: `sorted-dev`
- [ ] GoogleService-Info.plist downloaded and added to Xcode
- [ ] Firebase initialized in SortedApp.swift
- [ ] Firestore database created (test mode initially)
- [ ] Firebase Storage bucket created
- [ ] Firebase Authentication enabled (Email/Password)
- [ ] Firebase Cloud Messaging configured

**Technical Tasks:**
1. Create Firebase project at console.firebase.google.com
2. Register iOS app with bundle ID: `com.sorted.app.dev`
3. Download `GoogleService-Info.plist`
4. Add `GoogleService-Info.plist` to Xcode project (add to target)
5. Initialize Firebase in `SortedApp.swift`:
   ```swift
   import Firebase

   @main
   struct SortedApp: App {
       init() {
           FirebaseApp.configure()
       }
   }
   ```
6. Enable Authentication providers in Firebase Console:
   - Email/Password
7. Create Firestore database (start in test mode, will secure later)
8. Create Storage bucket with default rules
9. Enable Cloud Messaging and upload APNs certificate (can defer to Day 1)

---

### Story 0.4: Configure SwiftData ModelContainer
**As a developer, I need SwiftData set up for local persistence and offline queue.**

**Acceptance Criteria:**
- [ ] All 5 @Model entities defined (Message, Conversation, User, Attachment, FAQ)
- [ ] ModelContainer configured in SortedApp.swift
- [ ] Schema includes all relationships and cascade delete rules
- [ ] Preview container available for SwiftUI previews
- [ ] App builds and initializes SwiftData without errors

**Technical Tasks:**
1. Create `Core/Models/` directory
2. Copy @Model entities from SwiftData Implementation Guide:
   - `MessageEntity.swift`
   - `ConversationEntity.swift`
   - `UserEntity.swift`
   - `AttachmentEntity.swift`
   - `FAQEntity.swift`
3. Configure ModelContainer in `SortedApp.swift`:
   ```swift
   import SwiftData

   @main
   struct SortedApp: App {
       let modelContainer: ModelContainer

       init() {
           FirebaseApp.configure()

           do {
               modelContainer = try ModelContainer(
                   for: MessageEntity.self,
                        ConversationEntity.self,
                        UserEntity.self,
                        AttachmentEntity.self,
                        FAQEntity.self,
                   configurations: ModelConfiguration(
                       isStoredInMemoryOnly: false
                   )
               )
           } catch {
               fatalError("Failed to initialize ModelContainer: \(error)")
           }
       }

       var body: some Scene {
           WindowGroup {
               ContentView()
           }
           .modelContainer(modelContainer)
       }
   }
   ```
4. Test SwiftData initialization on simulator

**Reference:** See `docs/swiftdata-implementation-guide.md` for complete entity definitions

---

### Story 0.5: Create Project File Structure
**As a developer, I need the project organized following AI-first architecture principles.**

**Acceptance Criteria:**
- [ ] Feature-based folder structure created
- [ ] All folders follow naming convention
- [ ] Maximum 3 levels of folder depth
- [ ] File structure matches PRD Section 11.1
- [ ] README.md created with setup instructions

**Technical Tasks:**
1. Create folder structure:
   ```
   Sorted/
   ├── App/
   │   └── SortedApp.swift
   ├── Features/
   │   ├── Auth/
   │   │   ├── Views/
   │   │   ├── ViewModels/
   │   │   ├── Models/
   │   │   └── Services/
   │   ├── Chat/
   │   │   ├── Views/
   │   │   │   └── Components/
   │   │   ├── ViewModels/
   │   │   ├── Models/
   │   │   └── Repositories/
   │   ├── AI/
   │   │   ├── Views/
   │   │   │   └── Components/
   │   │   ├── ViewModels/
   │   │   ├── Models/
   │   │   └── Services/
   │   └── Settings/
   │       ├── Views/
   │       └── ViewModels/
   ├── Core/
   │   ├── Models/
   │   ├── Services/
   │   ├── Persistence/
   │   ├── Networking/
   │   ├── Theme/
   │   └── Utilities/
   ├── Resources/
   │   ├── GoogleService-Info.plist
   │   └── Assets.xcassets/
   └── Tests/
       ├── SortedTests/
       └── SortedUITests/
   ```

2. Create placeholder .swift files with headers in each directory
3. Create comprehensive README.md with:
   - Project overview
   - Setup instructions
   - Running the app
   - Firebase configuration steps
   - Testing instructions

---

### Story 0.6: Set Up Firebase Emulators (Optional but Recommended)
**As a developer, I want to run Firebase locally for faster development and offline testing.**

**Acceptance Criteria:**
- [ ] Firebase CLI installed globally
- [ ] Firebase emulators configured (Auth, Firestore, Storage, Functions)
- [ ] Emulator startup script created
- [ ] App can connect to emulators in Development configuration

**Technical Tasks:**
1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
2. Login to Firebase:
   ```bash
   firebase login
   ```
3. Initialize emulators in project root:
   ```bash
   firebase init emulators
   ```
   - Select: Auth, Firestore, Storage, Functions
   - Use default ports
4. Create `firebase.json` configuration
5. Create startup script `start-emulators.sh`:
   ```bash
   #!/bin/bash
   firebase emulators:start
   ```
6. Configure iOS app to use emulators in Development mode:
   ```swift
   #if DEBUG
   // Use emulators
   let settings = Firestore.firestore().settings
   settings.host = "localhost:8080"
   settings.isSSLEnabled = false
   Firestore.firestore().settings = settings

   Auth.auth().useEmulator(withHost: "localhost", port: 9099)
   #endif
   ```

**Note:** Can be deferred if time-constrained, but highly recommended for Day 1 development.

---

### Story 0.7: Initialize Git Repository
**As a developer, I need version control set up for the project.**

**Acceptance Criteria:**
- [ ] Git repository initialized
- [ ] Comprehensive .gitignore created (Xcode, Swift, Firebase)
- [ ] Initial commit created
- [ ] Remote repository linked (GitHub/GitLab)
- [ ] Main branch protected

**Technical Tasks:**
1. Initialize git repository:
   ```bash
   git init
   ```
2. Create `.gitignore`:
   ```
   # Xcode
   xcuserdata/
   *.xcworkspace
   build/
   DerivedData/
   *.pbxuser
   *.mode1v3
   *.mode2v3
   *.perspectivev3

   # Swift
   .DS_Store
   *.swp
   *~.nib

   # Firebase
   GoogleService-Info.plist
   .firebase/

   # Dependencies
   .build/
   Packages/

   # Secrets
   .env
   ```
3. Stage all files:
   ```bash
   git add .
   ```
4. Create initial commit:
   ```bash
   git commit -m "Initial project scaffolding with Firebase and SwiftData

   - Xcode project with Swift 6 + iOS 17+
   - Firebase SDK integrated (Auth, Firestore, Storage, FCM)
   - SwiftData ModelContainer with 5 core entities
   - Feature-based project structure
   - SPM dependencies (Firebase, Kingfisher)

   🤖 Generated with Claude Code

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```
5. Link to remote repository (if available)
6. Push initial commit

---

## Dependencies & Prerequisites

### Required Accounts:
- [ ] Apple Developer Account (for TestFlight in Day 7)
- [ ] Firebase/Google Cloud account (free tier OK for development)
- [ ] GitHub/GitLab account (for version control)

### Required Software:
- [ ] Xcode 15.0+ (with iOS 17 SDK)
- [ ] macOS 14.0+ (Sonoma or later)
- [ ] Node.js 18+ (for Firebase CLI and Cloud Functions)
- [ ] Git 2.0+

### Optional (Recommended):
- [ ] Firebase CLI (for emulators)
- [ ] CocoaPods (backup if SPM has issues)
- [ ] SF Symbols app (for iOS icons)

---

## Technical Implementation Notes

### Swift 6 Concurrency Configuration

Add to project build settings:
```
SWIFT_STRICT_CONCURRENCY = complete
```

### ModelContainer Configuration

The ModelContainer setup in `SortedApp.swift` should match the pattern from the SwiftData Implementation Guide (Section 5):

```swift
import SwiftUI
import SwiftData
import Firebase

@main
struct SortedApp: App {
    let modelContainer: ModelContainer

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        // Initialize SwiftData ModelContainer
        do {
            let schema = Schema([
                MessageEntity.self,
                ConversationEntity.self,
                UserEntity.self,
                AttachmentEntity.self,
                FAQEntity.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

### Firebase Initialization Best Practices

1. Always call `FirebaseApp.configure()` in `init()` before any other Firebase calls
2. Add `GoogleService-Info.plist` to Xcode target (verify it's included)
3. Use build configurations to separate Dev/Staging/Prod Firebase projects

---

## Testing & Verification

### Verification Checklist:
- [ ] App builds without errors in Xcode
- [ ] App runs on iOS Simulator (17.0+)
- [ ] Firebase initializes without errors (check console logs)
- [ ] SwiftData ModelContainer initializes successfully
- [ ] All SPM dependencies resolve and import correctly
- [ ] Project structure matches architecture specifications
- [ ] Git repository initialized with initial commit

### Test Procedure:
1. Clean build folder (⇧⌘K)
2. Build project (⌘B) - should succeed
3. Run on simulator (⌘R) - should launch
4. Check Xcode console for Firebase initialization logs
5. Verify no Swift 6 concurrency warnings/errors
6. Check SwiftData store file created (~/Library/Developer/CoreSimulator/...)

---

## Success Criteria

**Epic 0 is complete when:**
- ✅ Xcode project builds and runs without errors
- ✅ Firebase SDK integrated and initialized
- ✅ SwiftData ModelContainer configured with all 5 entities
- ✅ All SPM dependencies installed
- ✅ Project file structure matches architecture specifications
- ✅ Git repository initialized with initial commit
- ✅ README.md created with setup instructions
- ✅ Developer can begin Epic 1 (Authentication) immediately

---

## Time Estimates

| Story | Estimated Time |
|-------|---------------|
| 0.1 Initialize Xcode Project | 30 mins |
| 0.2 Install SPM Dependencies | 15 mins |
| 0.3 Set Up Firebase Backend | 45 mins |
| 0.4 Configure SwiftData ModelContainer | 30 mins |
| 0.5 Create Project File Structure | 30 mins |
| 0.6 Set Up Firebase Emulators (Optional) | 30 mins |
| 0.7 Initialize Git Repository | 15 mins |
| **Total** | **2-4 hours** |

---

## Implementation Order

**Recommended sequence:**
1. Story 0.1 (Xcode Project) - Foundation
2. Story 0.7 (Git Repository) - Version control early
3. Story 0.2 (SPM Dependencies) - Install packages
4. Story 0.3 (Firebase Backend) - Backend setup
5. Story 0.4 (SwiftData ModelContainer) - Local persistence
6. Story 0.5 (File Structure) - Organization
7. Story 0.6 (Firebase Emulators) - Optional, if time permits

---

## References

- **SwiftData Implementation Guide**: `docs/swiftdata-implementation-guide.md`
- **PRD Section 11**: File Structure & Organization
- **PRD Section 4**: Swift 6 & iOS 17+ Technical Standards
- **Architecture Doc Section 2**: Technology Stack

---

## Notes for Development Team

### Critical Decisions Made:
- **SwiftData over CoreData**: iOS 17+ requirement enables SwiftData usage
- **SPM over CocoaPods**: Swift Package Manager is Apple's preferred dependency manager
- **Firebase Emulators**: Optional but highly recommended for faster development cycles

### Potential Blockers:
- **Firebase account setup**: May require credit card for activation (free tier available)
- **Xcode download**: Large download, ensure stable internet
- **SPM package resolution**: Can be slow on first install, be patient

### Tips for Success:
- Run this epic completely before starting Day 1 MVP
- Verify everything works with a clean build before proceeding
- Document any deviations from this plan in project notes
- If Firebase Emulators cause issues, skip Story 0.6 and use live Firebase instead

---

**Epic Status:** Ready for implementation
**Blockers:** None
**Risk Level:** Low (standard iOS project setup)
