---
# Story 0.6: Set Up Firebase Emulators (Optional)

id: STORY-0.6
title: "Set Up Firebase Emulators for Local Development"
epic: "Epic 0: Project Scaffolding & Development Environment Setup"
status: skipped
priority: P2
estimate: 2
assigned_to: null
created_date: "2025-10-20"
sprint_day: 0
skipped_date: "2025-10-20"
skip_reason: "Optional story - using live Firebase services instead for faster initial setup"

---

## Description

**As a** developer
**I want** Firebase Emulators running locally (Auth, Firestore, Storage, Functions)
**So that** I can develop and test offline without consuming Firebase quota, with faster iteration cycles

This story sets up Firebase Emulators for local development, allowing developers to run Auth, Firestore, Storage, and Cloud Functions locally. This enables offline development, faster testing, and no Firebase usage quota consumption during development.

**Note:** This story is **OPTIONAL** but highly recommended. If time-constrained, developers can skip this and use live Firebase services instead.

---

## Acceptance Criteria

**This story is complete when:**

- [ ] Firebase CLI installed globally via npm
- [ ] Firebase emulators initialized (Auth, Firestore, Storage, Functions)
- [ ] Emulator configuration saved in `firebase.json`
- [ ] Emulator startup script created (`start-emulators.sh`)
- [ ] iOS app configured to use emulators in Development mode (#if DEBUG)
- [ ] Emulators start successfully and are accessible at localhost ports
- [ ] iOS app connects to emulators and can perform basic operations (auth, Firestore read/write)

---

## Technical Tasks

**Implementation steps:**

1. **Install Firebase CLI**
   - Open Terminal
   - Install Firebase CLI globally:
     ```bash
     npm install -g firebase-tools
     ```
   - Verify installation:
     ```bash
     firebase --version
     ```
   - Expected output: `12.9.0` or newer

2. **Login to Firebase**
   - Run login command:
     ```bash
     firebase login
     ```
   - Follow browser authentication flow
   - Verify login:
     ```bash
     firebase projects:list
     ```
   - Should show `sorted-dev` project

3. **Initialize Firebase Emulators**
   - Navigate to project root in Terminal
   - Run init command:
     ```bash
     firebase init emulators
     ```
   - Select project: `sorted-dev`
   - Select emulators to set up:
     - [x] Authentication Emulator
     - [x] Firestore Emulator
     - [x] Storage Emulator
     - [x] Functions Emulator
   - Use default ports:
     - Auth: 9099
     - Firestore: 8080
     - Storage: 9199
     - Functions: 5001
     - Emulator UI: 4000
   - Enable Emulator UI: Yes
   - Download emulators now: Yes

4. **Create firebase.json Configuration**
   - Firebase CLI will create `firebase.json`
   - Verify configuration matches:
     ```json
     {
       "emulators": {
         "auth": {
           "port": 9099
         },
         "firestore": {
           "port": 8080
         },
         "storage": {
           "port": 9199
         },
         "functions": {
           "port": 5001
         },
         "ui": {
           "enabled": true,
           "port": 4000
         }
       }
     }
     ```

5. **Create Emulator Startup Script**
   - Create file: `start-emulators.sh` in project root
   - Add contents:
     ```bash
     #!/bin/bash
     echo "🚀 Starting Firebase Emulators..."
     firebase emulators:start --import=./firebase-data --export-on-exit
     ```
   - Make script executable:
     ```bash
     chmod +x start-emulators.sh
     ```

6. **Configure iOS App to Use Emulators**
   - Open `SortedApp.swift`
   - Add emulator configuration in init() after FirebaseApp.configure():
     ```swift
     #if DEBUG
     // Use Firebase Emulators for local development
     print("🔧 Connecting to Firebase Emulators...")

     // Firestore Emulator
     let firestoreSettings = Firestore.firestore().settings
     firestoreSettings.host = "localhost:8080"
     firestoreSettings.isSSLEnabled = false
     Firestore.firestore().settings = firestoreSettings

     // Auth Emulator
     Auth.auth().useEmulator(withHost: "localhost", port: 9099)

     // Storage Emulator
     Storage.storage().useEmulator(withHost: "localhost", port: 9199)

     print("✅ Connected to Firebase Emulators")
     #endif
     ```

7. **Test Emulator Connection**
   - Start emulators:
     ```bash
     ./start-emulators.sh
     ```
   - Open Emulator UI: http://localhost:4000
   - Run iOS app in simulator
   - Check console for emulator connection logs
   - Verify app can create user in Auth Emulator

---

## Technical Specifications

### Files to Create

```
Project Root/
├── firebase.json (created by Firebase CLI)
├── .firebaserc (created by Firebase CLI)
├── start-emulators.sh (create)
└── firebase-data/ (created on first emulator run)
    └── (emulator data export)
```

### Files to Modify

```
Sorted/App/
└── SortedApp.swift (modify - add emulator config)
```

### Emulator Ports

```
Auth Emulator:       http://localhost:9099
Firestore Emulator:  http://localhost:8080
Storage Emulator:    http://localhost:9199
Functions Emulator:  http://localhost:5001
Emulator UI:         http://localhost:4000
```

### Code Examples

**SortedApp.swift (with Emulator Configuration):**
```swift
import SwiftUI
import SwiftData
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@main
struct SortedApp: App {
    let modelContainer: ModelContainer

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        #if DEBUG
        // Configure Firebase Emulators for local development
        configureEmulators()
        #endif

        // Initialize SwiftData (from Story 0.4)
        // ... ModelContainer setup ...
    }

    private func configureEmulators() {
        print("🔧 Connecting to Firebase Emulators...")

        // Firestore Emulator
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.host = "localhost:8080"
        firestoreSettings.isSSLEnabled = false
        Firestore.firestore().settings = firestoreSettings

        // Auth Emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        // Storage Emulator
        Storage.storage().useEmulator(withHost: "localhost", port: 9199)

        print("✅ Connected to Firebase Emulators")
        print("   Emulator UI: http://localhost:4000")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

**start-emulators.sh:**
```bash
#!/bin/bash

echo "🚀 Starting Firebase Emulators..."
echo "   Emulator UI will be available at: http://localhost:4000"
echo ""

# Start emulators with data import/export
firebase emulators:start --import=./firebase-data --export-on-exit

# --import: Load previously saved data
# --export-on-exit: Save data when emulators stop
```

### Dependencies

**Required:**
- Node.js 18+ installed
- Firebase CLI installed
- STORY-0.3 (Firebase Backend) complete

**Blocks:**
- None (optional story)

**External:**
- Internet connection (for Firebase CLI installation)

---

## Testing & Validation

### Test Procedure

1. **Firebase CLI Installation Test**
   ```bash
   firebase --version
   ```
   - Verify: Version 12.9.0 or newer

2. **Emulator Startup Test**
   ```bash
   ./start-emulators.sh
   ```
   - Verify: All emulators start without errors
   - Check output for:
     ```
     ✔  All emulators ready! It is now safe to connect your app.
     ┌─────────────────────────────────────────────────────────────┐
     │ ✔  All emulators ready! View status and logs at http://localhost:4000 │
     └─────────────────────────────────────────────────────────────┘
     ```

3. **Emulator UI Test**
   - Open browser: http://localhost:4000
   - Verify: Emulator UI loads
   - Check tabs: Authentication, Firestore, Storage, Functions

4. **iOS App Connection Test**
   - With emulators running, run iOS app (⌘R)
   - Check console for:
     ```
     🔧 Connecting to Firebase Emulators...
     ✅ Connected to Firebase Emulators
        Emulator UI: http://localhost:4000
     ```

5. **Auth Emulator Test**
   - Add test code to create user:
     ```swift
     Task {
         try? await Auth.auth().createUser(
             withEmail: "test@example.com",
             password: "password123"
         )
     }
     ```
   - Run app
   - Open Emulator UI → Authentication
   - Verify: Test user appears in emulator

6. **Firestore Emulator Test**
   - Add test code to write document:
     ```swift
     Task {
         try? await Firestore.firestore()
             .collection("test")
             .document("doc1")
             .setData(["message": "Hello from emulator!"])
     }
     ```
   - Run app
   - Open Emulator UI → Firestore
   - Verify: Document appears in emulator

### Success Criteria

- [ ] Firebase CLI installed and authenticated
- [ ] Emulators start successfully with `./start-emulators.sh`
- [ ] Emulator UI accessible at http://localhost:4000
- [ ] iOS app connects to emulators (verified in console logs)
- [ ] Can create users in Auth Emulator
- [ ] Can read/write to Firestore Emulator
- [ ] Data persists across emulator restarts (import/export works)

---

## References

**Architecture Docs:**
- [Technology Stack](../architecture/technology-stack.md#22-backend-services)

**Firebase Documentation:**
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Connect iOS to Emulators](https://firebase.google.com/docs/emulator-suite/connect_and_prototype)

**Epic:**
- [Epic 0: Project Scaffolding](../epics/epic-0-project-scaffolding.md#story-06-set-up-firebase-emulators-optional)

**Related Stories:**
- STORY-0.3: Set Up Firebase Backend (prerequisite)

---

## Notes & Considerations

### Implementation Notes

- **OPTIONAL STORY**: Can skip if time-constrained
  - Development can continue with live Firebase services
  - Emulators are highly recommended for faster iteration
- Emulators run locally - no Firebase quota consumed
- Data in emulators is ephemeral unless using --import/--export
- Emulator UI is extremely helpful for debugging

### Edge Cases

- **Port Conflicts**: If ports are already in use, emulators will fail to start
  - Solution: Change ports in firebase.json or kill conflicting processes
- **Emulator Data Loss**: Without --export-on-exit, data is lost on emulator stop
  - Solution: Always use startup script with data export
- **iOS Simulator Network**: Emulators on localhost work with iOS Simulator
  - Physical devices cannot access localhost - use live Firebase instead

### Performance Considerations

- Emulators are significantly faster than live Firebase (no network latency)
- First emulator startup is slow (~30 seconds)
- Subsequent starts are faster (~5 seconds)
- Data import/export adds ~2-3 seconds to startup/shutdown

### Security Considerations

- Emulators have NO security rules enforcement by default
  - All reads/writes are allowed - similar to test mode
- Emulator data is local-only - not synced to production Firebase
- Do NOT use emulators for production or staging environments

---

## Metadata

**Created by:** SM Agent (Bob)
**Created date:** 2025-10-20
**Last updated:** 2025-10-20
**Sprint:** Day 0 of 7-day sprint
**Epic:** Epic 0: Project Scaffolding
**Story points:** 2
**Priority:** P2 (Medium - Optional)

---

## Story Lifecycle

- [x] **Draft** - Story created, needs review
- [ ] **Ready** - Story reviewed and ready for development
- [ ] **In Progress** - Developer working on story
- [ ] **Blocked** - Story blocked by dependency or issue
- [ ] **Review** - Implementation complete, needs QA review
- [ ] **Done** - Story complete and validated
- [x] **Skipped** - Story skipped (optional, deferred, or not needed)

**Current Status:** Skipped
**Skip Reason:** Optional story - using live Firebase services instead for faster initial setup. Can be implemented later if offline development or faster iteration cycles are needed.
