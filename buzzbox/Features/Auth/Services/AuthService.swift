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
// import FirebaseDatabase // TODO: Add FirebaseDatabase package to project
import SwiftData
import Kingfisher

/// Main authentication service
@MainActor
final class AuthService: ObservableObject {
    // MARK: - Properties

    private let auth: Auth
    private let firestore: Firestore
    // private let database: Database // TODO: Re-enable when FirebaseDatabase is added
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
        // database: Database = Database.database(), // TODO: Re-enable when FirebaseDatabase is added
        displayNameService: DisplayNameService = DisplayNameService()
    ) {
        self.auth = auth
        self.firestore = firestore
        // self.database = database // TODO: Re-enable when FirebaseDatabase is added
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
                print("🔐 Auth state changed: \(user?.email ?? "Not signed in")")
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
        // 1. Validate displayName format (client-side)
        guard isValidDisplayName(displayName) else {
            throw AuthError.invalidDisplayName
        }

        // 2. Check displayName availability
        let isAvailable = try await displayNameService.checkAvailability(displayName)
        guard isAvailable else {
            throw AuthError.displayNameTaken
        }

        // 3. Create Firebase Auth user
        do {
            print("🔐 Creating Firebase Auth user for: \(email)")
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let uid = authResult.user.uid
            print("✅ Firebase Auth user created: \(uid)")

            // 4. Reserve displayName in Firestore (for uniqueness)
            try await displayNameService.reserveDisplayName(displayName, userId: uid)

            // 5. Create Firestore user document
            let userData: [String: Any] = [
                "email": email,
                "displayName": displayName,
                "photoURL": "",
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await firestore.collection("users").document(uid).setData(userData)

            // 6. Initialize user presence in Realtime Database
            // TODO: Re-enable when FirebaseDatabase is added
            // let presenceRef = database.reference().child("userPresence").child(uid)
            // try await presenceRef.setValue([
            //     "status": "online",
            //     "lastSeen": ServerValue.timestamp()
            // ])

            // 7. Create local SwiftData UserEntity
            let userEntity = UserEntity(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: nil,
                createdAt: Date()
            )
            modelContext.insert(userEntity)
            try modelContext.save()

            // 8. Create and return User struct
            let user = User(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: nil,
                createdAt: Date()
            )

            // Update published state
            self.currentUser = user
            self.isAuthenticated = true

            return user

        } catch let error as NSError {
            // Print detailed error information
            print("❌ Firebase createUser error:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            print("   UserInfo: \(error.userInfo)")

            // Map Firebase errors to AuthError
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

    /// Validate password strength
    /// - Parameter password: Password to validate
    /// - Returns: `true` if valid (8+ characters), `false` otherwise
    func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
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
        do {
            // 1. Sign in with Firebase Auth
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let uid = authResult.user.uid

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

            // 6. Create User object
            let user = User(
                id: uid,
                email: userEmail,
                displayName: displayName,
                photoURL: photoURL,
                createdAt: createdAt
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
            } else {
                // Create new user entity
                let userEntity = UserEntity(
                    id: uid,
                    email: userEmail,
                    displayName: displayName,
                    photoURL: photoURL,
                    createdAt: createdAt
                )
                modelContext.insert(userEntity)
            }
            try modelContext.save()

            // 8. Update user presence in Realtime Database
            // TODO: Re-enable when FirebaseDatabase is added
            // let presenceRef = database.reference().child("userPresence").child(uid)
            // try await presenceRef.updateChildValues([
            //     "status": "online",
            //     "lastSeen": ServerValue.timestamp()
            // ])

            // 9. Update published state
            self.currentUser = user
            self.isAuthenticated = true

            return user

        } catch let error as NSError {
            // Map Firebase errors to AuthError
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

    // MARK: - Auto Login

    /// Attempts auto-login using stored Keychain token
    /// - Parameter modelContext: SwiftData ModelContext for local persistence
    /// - Returns: User object if auto-login successful, nil if no valid token
    /// - Throws: AuthError if token exists but is invalid
    func autoLogin(modelContext: ModelContext) async throws -> User? {
        // 1. Check Keychain for stored token
        let keychainService = KeychainService()
        guard let token = keychainService.retrieve() else {
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

        // 7. Create User object
        let user = User(
            id: uid,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            createdAt: createdAt
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
        } else {
            // Create new user entity
            let userEntity = UserEntity(
                id: uid,
                email: email,
                displayName: displayName,
                photoURL: photoURL,
                createdAt: createdAt
            )
            modelContext.insert(userEntity)
        }
        try modelContext.save()

        // 9. Update user presence in Realtime Database
        // TODO: Re-enable when FirebaseDatabase is added
        // let presenceRef = database.reference().child("userPresence").child(uid)
        // try await presenceRef.updateChildValues([
        //     "status": "online",
        //     "lastSeen": ServerValue.timestamp()
        // ])

        // 10. Update published state
        self.currentUser = user
        self.isAuthenticated = true

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
    /// - Throws: AuthError if sign out fails
    func signOut() async throws {
        // 1. Sign out from Firebase Auth
        do {
            try auth.signOut()
        } catch {
            throw mapFirebaseError(error as NSError)
        }

        // 2. Delete auth token from Keychain
        let keychainService = KeychainService()
        try keychainService.delete()

        // 3. Clear Kingfisher image cache
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()

        // 4. Update published state
        self.currentUser = nil
        self.isAuthenticated = false
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

        // 2. Prepare update data
        var updateData: [String: Any] = [:]
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL.absoluteString
        }

        // 3. Update Firestore user document
        try await firestore.collection("users").document(uid).updateData(updateData)

        // 4. Update Realtime Database presence (optional: add displayName for quick lookup)
        // TODO: Re-enable when FirebaseDatabase is added
        // if let displayName = displayName {
        //     let presenceRef = database.reference().child("userPresence").child(uid)
        //     try await presenceRef.updateChildValues(["displayName": displayName])
        // }

        // 5. Update local SwiftData UserEntity
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

        // 6. Update published currentUser
        if let user = self.currentUser {
            self.currentUser = User(
                id: user.id,
                email: user.email,
                displayName: displayName ?? user.displayName,
                photoURL: photoURL?.absoluteString ?? user.photoURL,
                createdAt: user.createdAt
            )
        }
    }
}
