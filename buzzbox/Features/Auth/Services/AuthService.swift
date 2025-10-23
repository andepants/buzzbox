/// AuthService.swift
/// Handles Firebase Auth operations for sign up, login, and session management
/// [Source: Epic 1, Story 1.1]
///
/// Central service for all authentication operations including:
/// - User sign up with email/password
/// - Display name validation and reservation
/// - Firestore profile creation
/// - SwiftData local persistence
/// - Realtime Database presence initialization

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
@preconcurrency import FirebaseDatabase
import SwiftData
import Kingfisher

/// Main authentication service
@MainActor
final class AuthService: ObservableObject {
    // MARK: - Properties

    private let auth: Auth
    private let firestore: Firestore
    nonisolated(unsafe) private let database: DatabaseReference
    private let displayNameService: DisplayNameService

    /// Current authenticated user (observable)
    @Published private(set) var currentUser: User?

    /// Authentication state (true if logged in)
    @Published private(set) var isAuthenticated: Bool = false

    /// Auth state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Initialization

    /// Initialize with optional dependencies (useful for testing)
    init(
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore(),
        database: DatabaseReference = Database.database().reference(),
        displayNameService: DisplayNameService = DisplayNameService()
    ) {
        self.auth = auth
        self.firestore = firestore
        self.database = database
        self.displayNameService = displayNameService

        // Set up auth state listener (recommended by Firebase docs)
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener

    /// Sets up Firebase Auth state listener to automatically track auth changes
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                self.isAuthenticated = user != nil
            }
        }
    }

    // Note: No deinit needed - Firebase Auth automatically cleans up listeners
    // when the Auth instance is deallocated

    // MARK: - Sign Up

    /// Create a new user account
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: User's chosen display name
    ///   - modelContext: SwiftData ModelContext for local persistence
    /// - Returns: The created User object
    /// - Throws: AuthError for validation/Firebase errors
    func createUser(
        email: String,
        password: String,
        displayName: String,
        modelContext: ModelContext
    ) async throws -> User {
        print("🔵 [AUTH] Starting sign-up for email: \(email), displayName: \(displayName)")

        // 1. Validate displayName format (client-side)
        guard isValidDisplayName(displayName) else {
            print("🔴 [AUTH] Sign-up failed: Invalid display name format")
            throw AuthError.invalidDisplayName
        }

        // 2. Check displayName availability
        let isAvailable = try await displayNameService.checkAvailability(displayName)
        guard isAvailable else {
            throw AuthError.displayNameTaken
        }

        // 3. Create Firebase Auth user
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let uid = authResult.user.uid

            // 3a. Update Firebase Auth profile with displayName (recommended by Firebase)
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // 4. Reserve displayName in Firestore (for uniqueness)
            try await displayNameService.reserveDisplayName(displayName, userId: uid)

            // 5. Determine user type based on email
            let userType: UserType = email.lowercased() == CREATOR_EMAIL.lowercased() ? .creator : .fan
            let isPublic = userType == .creator

            // 6. Create Firestore user document
            let userData: [String: Any] = [
                "email": email,
                "displayName": displayName,
                "photoURL": "",
                "userType": userType.rawValue,
                "isPublic": isPublic,
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await firestore.collection("users").document(uid).setData(userData)

            // 7. Create user profile in Realtime Database (for conversation validation)
            print("🔵 [AUTH] Creating user profile in RTDB...")
            let userRef = database.child("users").child(uid)
            try await userRef.setValue([
                "email": email,
                "displayName": displayName,
                "profilePictureURL": "",
                "userType": userType.rawValue,
                "isPublic": isPublic,
                "createdAt": ServerValue.timestamp()
            ])
            print("✅ [AUTH] User profile created in RTDB")

            // 8. Initialize user presence in Realtime Database
            let presenceRef = database.child("userPresence").child(uid)
            try await presenceRef.setValue([
                "status": "online",
                "lastSeen": ServerValue.timestamp()
            ])

            // 9. Create local SwiftData UserEntity
            let userEntity = UserEntity(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: nil,
                createdAt: Date(),
                userType: userType,
                isPublic: isPublic
            )
            modelContext.insert(userEntity)
            try modelContext.save()

            // 10. Auto-join user to default channels
            print("🔵 [AUTH] Auto-joining user to default channels...")
            do {
                try await ConversationService.shared.autoJoinDefaultChannels(userID: uid)
            } catch {
                // Log but don't fail signup - channels are non-critical
                print("⚠️ [AUTH] Failed to auto-join channels (non-critical): \(error.localizedDescription)")
            }

            // 11. Auto-create DM with creator (Andrew) for fans only
            if userType == .fan {
                print("🔵 [AUTH] Auto-creating DM with creator for new fan...")
                do {
                    // Create the conversation
                    let conversationID = try await ConversationService.shared.autoCreateDMWithCreator(
                        fanUserID: uid,
                        creatorEmail: CREATOR_EMAIL
                    )

                    // Find creator's UID to send welcome message
                    let creatorSnapshot = try await firestore
                        .collection("users")
                        .whereField("email", isEqualTo: CREATOR_EMAIL)
                        .limit(to: 1)
                        .getDocuments()

                    if let creatorDoc = creatorSnapshot.documents.first {
                        let creatorID = creatorDoc.documentID

                        // Send welcome message from Andrew
                        let welcomeMessage = "Thanks for checking out my app! Please share any advice you have :)"
                        try await ConversationService.shared.sendWelcomeMessage(
                            text: welcomeMessage,
                            conversationID: conversationID,
                            senderID: creatorID
                        )
                        print("✅ [AUTH] DM created and welcome message sent to conversation \(conversationID)")
                    }
                } catch {
                    // Log but don't fail signup - DM creation is non-critical
                    print("⚠️ [AUTH] Failed to auto-create DM with creator (non-critical): \(error.localizedDescription)")
                }
            }

            // 12. Create and return User struct
            let user = User(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: nil,
                createdAt: Date(),
                userType: userType,
                isPublic: isPublic
            )

            // Update published state
            self.currentUser = user
            self.isAuthenticated = true

            print("✅ [AUTH] Sign-up successful for uid: \(uid)")
            return user

        } catch let error as NSError {
            print("🔴 [AUTH] Sign-up failed: \(error.localizedDescription)")

            // Check if this is a Database error
            if error.domain == "FirebaseDatabase" ||
               error.localizedDescription.contains("permission_denied") {
                throw mapDatabaseError(error)
            }

            // Map Firebase Auth errors to AuthError
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Validation

    /// Validate display name format (Instagram-style)
    /// - Parameter name: Display name to validate
    /// - Returns: `true` if valid, `false` otherwise
    func isValidDisplayName(_ name: String) -> Bool {
        // Length: 3-30 characters
        guard name.count >= 3 && name.count <= 30 else { return false }

        // Alphanumeric + underscore + period only
        guard name.range(of: "^[a-zA-Z0-9._]+$", options: .regularExpression) != nil else {
            return false
        }

        // Cannot start or end with period
        guard !name.hasPrefix(".") && !name.hasSuffix(".") else { return false }

        // No consecutive periods
        guard !name.contains("..") else { return false }

        return true
    }

    /// Validate email format
    /// - Parameter email: Email to validate
    /// - Returns: `true` if valid, `false` otherwise
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Validate password strength (Firebase minimum is 6 characters)
    /// - Parameter password: Password to validate
    /// - Returns: `true` if valid (6+ characters), `false` otherwise
    func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }

    // MARK: - Sign In

    /// Signs in user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - modelContext: SwiftData ModelContext for local persistence
    /// - Returns: User object with synced data from Firestore
    /// - Throws: AuthError if login fails
    func signIn(
        email: String,
        password: String,
        modelContext: ModelContext
    ) async throws -> User {
        print("🔵 [AUTH] Starting sign-in for email: \(email)")

        do {
            // 1. Sign in with Firebase Auth
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let uid = authResult.user.uid
            print("🔵 [AUTH] Firebase Auth successful for uid: \(uid)")

            // 2. Get ID token for Keychain storage
            let idToken = try await authResult.user.getIDToken()

            // 3. Store token in Keychain
            let keychainService = KeychainService()
            try keychainService.save(token: idToken)

            // 4. Fetch user data from Firestore
            let userDoc = try await firestore.collection("users").document(uid).getDocument()

            guard let data = userDoc.data() else {
                throw AuthError.userNotFound
            }

            // 5. Parse user data
            let userEmail = data["email"] as? String ?? email
            let displayName = data["displayName"] as? String ?? ""
            let photoURL = data["photoURL"] as? String
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

            // Parse userType and isPublic (with fallback to email-based assignment)
            let userTypeRaw = data["userType"] as? String
            let userType: UserType
            if let userTypeRaw = userTypeRaw, let parsedType = UserType(rawValue: userTypeRaw) {
                userType = parsedType
            } else {
                // Fallback: auto-assign based on email
                userType = userEmail.lowercased() == CREATOR_EMAIL.lowercased() ? .creator : .fan
            }
            let isPublic = data["isPublic"] as? Bool ?? (userType == .creator)

            // 5a. Sync displayName to Firebase Auth profile if it differs
            if authResult.user.displayName != displayName {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }

            // 5b. Sync photoURL to Firebase Auth profile if it differs
            if let photoURL = photoURL, let url = URL(string: photoURL) {
                if authResult.user.photoURL?.absoluteString != photoURL {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.photoURL = url
                    try await changeRequest.commitChanges()
                }
            }

            // 6. Create User object
            let user = User(
                id: uid,
                email: userEmail,
                displayName: displayName,
                photoURL: photoURL,
                createdAt: createdAt,
                userType: userType,
                isPublic: isPublic
            )

            // 7. Update local SwiftData UserEntity (upsert pattern)
            let descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate { $0.id == uid }
            )
            let existingUsers = try modelContext.fetch(descriptor)

            if let existingUser = existingUsers.first {
                // Update existing user
                existingUser.email = userEmail
                existingUser.displayName = displayName
                existingUser.photoURL = photoURL
                existingUser.userType = userType
                existingUser.isPublic = isPublic
            } else {
                // Create new user entity
                let userEntity = UserEntity(
                    id: uid,
                    email: userEmail,
                    displayName: displayName,
                    photoURL: photoURL,
                    createdAt: createdAt,
                    userType: userType,
                    isPublic: isPublic
                )
                modelContext.insert(userEntity)
            }
            try modelContext.save()

            // 8. Ensure user exists in Realtime Database (for conversation validation)
            print("🔵 [AUTH] Writing user profile to RTDB...")
            let userRef = database.child("users").child(uid)
            try await userRef.setValue([
                "email": userEmail,
                "displayName": displayName,
                "profilePictureURL": photoURL ?? "",
                "userType": userType.rawValue,
                "isPublic": isPublic,
                "updatedAt": ServerValue.timestamp()
            ])
            print("✅ [AUTH] User profile written to RTDB")

            // 9. Update user presence in Realtime Database
            let presenceRef = database.child("userPresence").child(uid)
            try await presenceRef.updateChildValues([
                "status": "online",
                "lastSeen": ServerValue.timestamp()
            ])

            // 10. Update published state
            self.currentUser = user
            self.isAuthenticated = true

            print("✅ [AUTH] Sign-in successful for uid: \(uid)")
            return user

        } catch let error as NSError {
            print("🔴 [AUTH] Sign-in failed: \(error.localizedDescription)")

            // Check if this is a Database error
            if error.domain == "FirebaseDatabase" ||
               error.localizedDescription.contains("permission_denied") {
                throw mapDatabaseError(error)
            }

            // Otherwise, map as Auth error
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Error Mapping

    /// Map Firebase Auth errors to custom AuthError
    /// - Parameter error: NSError from Firebase
    /// - Returns: Mapped AuthError
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard error.domain == AuthErrorDomain else {
            return .unknownError(error.localizedDescription)
        }

        switch AuthErrorCode(_nsError: error).code {
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .invalidEmail:
            return .invalidEmail
        case .networkError:
            return .networkError
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .userDisabled:
            return .userDisabled
        case .tooManyRequests:
            return .tooManyRequests
        default:
            return .unknownError(error.localizedDescription)
        }
    }

    /// Map Firebase Database errors to custom AuthError
    /// - Parameter error: Error from Firebase Realtime Database
    /// - Returns: Mapped AuthError
    private func mapDatabaseError(_ error: Error) -> AuthError {
        let nsError = error as NSError

        // Log for developers
        print("🔴 [AUTH-DB-ERROR] \(nsError.domain) | Code: \(nsError.code)")
        print("   Description: \(nsError.localizedDescription)")
        print("   User Info: \(nsError.userInfo)")

        // Check for permission_denied
        if nsError.localizedDescription.contains("permission_denied") {
            return .databasePermissionDenied
        }

        // Check for network errors
        if nsError.domain == NSURLErrorDomain {
            return .databaseNetworkError
        }

        return .databaseWriteFailed(nsError.localizedDescription)
    }

    // MARK: - Auto Login

    /// Attempts auto-login using stored Keychain token
    /// - Parameter modelContext: SwiftData ModelContext for local persistence
    /// - Returns: User object if auto-login successful, nil if no valid token
    /// - Throws: AuthError if token exists but is invalid
    func autoLogin(modelContext: ModelContext) async throws -> User? {
        print("🔵 [AUTH] Attempting auto-login...")

        // 1. Check Keychain for stored token
        let keychainService = KeychainService()
        guard let token = keychainService.retrieve() else {
            print("⚠️ [AUTH] No token found in Keychain, auto-login skipped")
            return nil // No token stored, user needs to login
        }

        // 2. Verify Firebase Auth current user
        guard let firebaseUser = auth.currentUser else {
            // Token exists but no Firebase user - clear invalid token
            try? keychainService.delete()
            return nil
        }

        // 3. Refresh token if needed (Firebase SDK handles this automatically)
        let idToken = try await firebaseUser.getIDToken()

        // 4. Update Keychain with refreshed token
        try keychainService.save(token: idToken)

        // 5. Fetch user data from Firestore
        let uid = firebaseUser.uid
        let userDoc = try await firestore.collection("users").document(uid).getDocument()

        guard let data = userDoc.data() else {
            throw AuthError.userNotFound
        }

        // 6. Parse user data
        let email = data["email"] as? String ?? ""
        let displayName = data["displayName"] as? String ?? ""
        let photoURL = data["photoURL"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        // Parse userType and isPublic (with fallback to email-based assignment)
        let userTypeRaw = data["userType"] as? String
        let userType: UserType
        if let userTypeRaw = userTypeRaw, let parsedType = UserType(rawValue: userTypeRaw) {
            userType = parsedType
        } else {
            // Fallback: auto-assign based on email
            userType = email.lowercased() == CREATOR_EMAIL.lowercased() ? .creator : .fan
        }
        let isPublic = data["isPublic"] as? Bool ?? (userType == .creator)

        // 6a. Sync displayName to Firebase Auth profile if it differs
        if firebaseUser.displayName != displayName {
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }

        // 6b. Sync photoURL to Firebase Auth profile if it differs
        if let photoURL = photoURL, let url = URL(string: photoURL) {
            if firebaseUser.photoURL?.absoluteString != photoURL {
                let changeRequest = firebaseUser.createProfileChangeRequest()
                changeRequest.photoURL = url
                try await changeRequest.commitChanges()
            }
        }

        // 7. Create User object
        let user = User(
            id: uid,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            createdAt: createdAt,
            userType: userType,
            isPublic: isPublic
        )

        // 8. Update local SwiftData UserEntity (upsert pattern)
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.id == uid }
        )
        let existingUsers = try modelContext.fetch(descriptor)

        if let existingUser = existingUsers.first {
            // Update existing user
            existingUser.email = email
            existingUser.displayName = displayName
            existingUser.photoURL = photoURL
            existingUser.userType = userType
            existingUser.isPublic = isPublic
        } else {
            // Create new user entity
            let userEntity = UserEntity(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: photoURL,
                createdAt: createdAt,
                userType: userType,
                isPublic: isPublic
            )
            modelContext.insert(userEntity)
        }
        try modelContext.save()

        // 9. Ensure user exists in Realtime Database (for conversation validation)
        print("🔵 [AUTH] Syncing user profile to RTDB...")
        let userRef = database.child("users").child(uid)
        try await userRef.setValue([
            "email": email,
            "displayName": displayName,
            "profilePictureURL": photoURL ?? "",
            "userType": userType.rawValue,
            "isPublic": isPublic,
            "updatedAt": ServerValue.timestamp()
        ])
        print("✅ [AUTH] User profile synced to RTDB")

        // 10. Update user presence in Realtime Database
        let presenceRef = database.child("userPresence").child(uid)
        try await presenceRef.updateChildValues([
            "status": "online",
            "lastSeen": ServerValue.timestamp()
        ])

        // 11. Update published state
        self.currentUser = user
        self.isAuthenticated = true

        print("✅ [AUTH] Auto-login successful for uid: \(uid)")
        return user
    }

    /// Refreshes auth token if app was in background for > 1 hour
    /// - Parameter lastActiveDate: Date when app was last active
    func refreshAuthIfNeeded(lastActiveDate: Date) async throws {
        let oneHour: TimeInterval = 3600
        let timeSinceLastActive = Date().timeIntervalSince(lastActiveDate)

        guard timeSinceLastActive > oneHour else {
            return // No refresh needed
        }

        guard let firebaseUser = auth.currentUser else {
            return
        }

        // Force token refresh
        let idToken = try await firebaseUser.getIDToken()

        // Update Keychain with refreshed token
        let keychainService = KeychainService()
        try keychainService.save(token: idToken)
    }

    // MARK: - Password Reset

    /// Sends password reset email to user
    /// - Parameter email: User's email address
    /// - Throws: AuthError if email send fails
    func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign Out

    /// Signs out user and cleans up local data
    /// - Note: Non-throwing to ensure cleanup always completes
    func signOut() async throws {
        print("🔵 [AUTH] Starting sign-out...")

        // 1. Remove all Firebase listeners FIRST (prevents post-logout observer fires)
        await UserPresenceService.shared.removeAllListeners()
        print("✅ [AUTH] Firebase listeners removed")

        // 2. Set user offline in Realtime Database (non-blocking, with timeout)
        await UserPresenceService.shared.setOffline()
        print("✅ [AUTH] User presence set to offline")

        // 3. Sign out from Firebase Auth
        do {
            try auth.signOut()
            print("✅ [AUTH] Firebase Auth sign-out successful")
        } catch {
            print("🔴 [AUTH] Firebase sign-out failed: \(error)")
            // Don't throw - continue cleanup
        }

        // 4. Delete auth token from Keychain
        let keychainService = KeychainService()
        do {
            try keychainService.delete()
            print("✅ [AUTH] Keychain token deleted")
        } catch {
            print("⚠️ [AUTH] Keychain deletion failed (non-critical): \(error)")
            // Continue cleanup even if Keychain fails
        }

        // 5. Clear Kingfisher image cache
        await Task.detached(priority: .background) {
            KingfisherManager.shared.cache.clearMemoryCache()
            KingfisherManager.shared.cache.clearDiskCache()
        }.value
        print("✅ [AUTH] Kingfisher cache cleared")

        // 6. Update published state (always succeeds)
        self.currentUser = nil
        self.isAuthenticated = false

        print("✅ [AUTH] Sign-out completed successfully")
    }

    // MARK: - Profile Management

    /// Updates user profile (displayName and/or photoURL)
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - photoURL: New profile picture URL (optional)
    ///   - modelContext: SwiftData ModelContext for local persistence
    /// - Throws: AuthError if update fails
    func updateUserProfile(
        displayName: String?,
        photoURL: URL?,
        modelContext: ModelContext
    ) async throws {
        guard let currentUser = auth.currentUser else {
            throw AuthError.userNotFound
        }

        let uid = currentUser.uid

        // 1. Handle displayName change (if provided)
        if let newDisplayName = displayName {
            // Fetch current displayName from Firestore
            let userDoc = try await firestore.collection("users").document(uid).getDocument()
            let currentDisplayName = userDoc.data()?["displayName"] as? String

            // Only process if displayName actually changed
            if newDisplayName != currentDisplayName {
                // Validate format
                guard isValidDisplayName(newDisplayName) else {
                    throw AuthError.invalidDisplayName
                }

                // Check availability
                let isAvailable = try await displayNameService.checkAvailability(newDisplayName)
                guard isAvailable else {
                    throw AuthError.displayNameTaken
                }

                // Release old displayName claim
                if let oldDisplayName = currentDisplayName {
                    try await displayNameService.releaseDisplayName(oldDisplayName, userId: uid)
                }

                // Reserve new displayName
                try await displayNameService.reserveDisplayName(newDisplayName, userId: uid)
            }
        }

        // 2. Update Firebase Auth profile first (source of truth for Auth)
        let changeRequest = currentUser.createProfileChangeRequest()
        var profileUpdated = false

        if let displayName = displayName {
            changeRequest.displayName = displayName
            profileUpdated = true
        }
        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
            profileUpdated = true
        }

        if profileUpdated {
            try await changeRequest.commitChanges()
        }

        // 3. Prepare update data for Firestore
        var updateData: [String: Any] = [:]
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL.absoluteString
        }

        // 4. Update Firestore user document
        try await firestore.collection("users").document(uid).updateData(updateData)

        // 5. Update Realtime Database user profile
        var rtdbUpdateData: [String: Any] = [:]
        if let displayName = displayName {
            rtdbUpdateData["displayName"] = displayName
        }
        if let photoURL = photoURL {
            rtdbUpdateData["profilePictureURL"] = photoURL.absoluteString
        }
        rtdbUpdateData["updatedAt"] = ServerValue.timestamp()

        let userRef = database.child("users").child(uid)
        try await userRef.updateChildValues(rtdbUpdateData)

        // 6. Update local SwiftData UserEntity
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.id == uid }
        )
        let existingUsers = try modelContext.fetch(descriptor)

        if let existingUser = existingUsers.first {
            existingUser.updateProfile(
                displayName: displayName,
                photoURL: photoURL?.absoluteString
            )
            try modelContext.save()
        }

        // 7. Update published currentUser
        if let user = self.currentUser {
            self.currentUser = User(
                id: user.id,
                email: user.email,
                displayName: displayName ?? user.displayName,
                photoURL: photoURL?.absoluteString ?? user.photoURL,
                createdAt: user.createdAt,
                userType: user.userType,
                isPublic: user.isPublic
            )
        }
    }
}
