# Technology Stack

### 2.1 iOS Technologies (Non-Negotiable)

```
Language:           Swift 6
UI Framework:       SwiftUI (iOS 17+)
Concurrency:        Swift Concurrency (async/await, @MainActor)
Local Database:     SwiftData
Secure Storage:     Keychain Services
Networking:         URLSession
Package Manager:    Swift Package Manager (SPM)
Min iOS Version:    iOS 17.0
```

### 2.2 Backend Services (Firebase)

```
Authentication:     Firebase Auth
Database:           Cloud Firestore (User profiles, static data)
Real-time Database: Firebase Realtime Database (Chat, typing indicators, presence)
Push Notifications: Firebase Cloud Messaging (FCM)
Storage:            Firebase Storage (Media files)
Serverless:         Cloud Functions (Node.js 18)
Analytics:          Firebase Analytics
Crash Reporting:    Firebase Crashlytics
```

**Important:** Use Realtime Database for ALL real-time features (chat messages, typing indicators, user presence). Use Firestore for static/profile data only.

### 2.3 AI Services

```
Primary AI:         OpenAI GPT-4 (via Cloud Functions)
Alternative:        Anthropic Claude 3.5 Sonnet
RAG System:         Supermemory API (conversation context)
Vector DB:          Built into Supermemory
Embeddings:         OpenAI text-embedding-3-small
```

### 2.4 Required Dependencies (SPM)

```
Firebase iOS SDK 10.20+    (Auth, Firestore, Messaging, Storage)
Kingfisher 7.10+           (Image loading & caching)
PopupView 2.8+             (Toasts & alerts)
ActivityIndicatorView 1.1+ (Loading states)
MediaPicker 1.0+           (Image/video selection)
SwiftUI Introspect 1.1+    (UIKit access for keyboard handling)
OpenAI Swift 1.8+          (Optional - can use URLSession)
```
