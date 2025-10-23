/// MessageThreadViewModel.swift
///
/// Manages message thread state with RTDB real-time streaming.
/// Handles optimistic UI, message sending, and real-time message delivery.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages, RTDB Code Examples lines 904-1113]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore
@preconcurrency import FirebaseDatabase

/// ViewModel for message thread with real-time RTDB streaming
@MainActor
@Observable
final class MessageThreadViewModel {
    // MARK: - Properties

    var isLoading = false
    var error: Error?

    // MARK: - Private Properties

    private let conversationID: String
    private let modelContext: ModelContext
    private var messagesRef: DatabaseReference

    private var childAddedHandle: DatabaseHandle?
    private var childChangedHandle: DatabaseHandle?

    // MARK: - Initialization

    init(conversationID: String, modelContext: ModelContext) {
        self.conversationID = conversationID
        self.modelContext = modelContext
        self.messagesRef = Database.database().reference().child("messages/\(conversationID)")
    }

    // MARK: - Public Methods

    /// Sends a message with optimistic UI and RTDB sync
    func sendMessage(text: String) async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }

        // Create message with client-side timestamp (for immediate display)
        let messageID = UUID().uuidString
        let message = MessageEntity(
            id: messageID,
            conversationID: conversationID,
            senderID: currentUserID,
            text: text,
            localCreatedAt: Date(), // Client timestamp for display
            serverTimestamp: nil, // Will be set by RTDB
            sequenceNumber: nil, // Will be set by RTDB
            status: .sent,
            syncStatus: .pending
        )

        // Save locally first (optimistic UI)
        modelContext.insert(message)
        try? modelContext.save()

        // Sync to RTDB in background
        Task { @MainActor in
            do {
                // Push to RTDB (generates server timestamp)
                let messageData: [String: Any] = [
                    "senderID": message.senderID,
                    "text": message.text,
                    "serverTimestamp": ServerValue.timestamp(),
                    "status": "sent"
                ]

                try await messagesRef.child(messageID).setValue(messageData)

                // Update local sync status
                message.syncStatus = .synced
                try? modelContext.save()

                // Update conversation last message
                await updateConversationLastMessage(text: text)

            } catch {
                // Mark as failed
                message.syncStatus = .failed
                message.syncError = error.localizedDescription
                self.error = error
                try? modelContext.save()
            }
        }
    }

    /// Starts real-time RTDB listener for messages
    func startRealtimeListener() async {
        // Listen for new messages via RTDB observe
        childAddedHandle = messagesRef
            .queryOrdered(byChild: "serverTimestamp")
            .queryLimited(toLast: 100) // Load recent 100 messages
            .observe(.childAdded, with: { [weak self] snapshot in
                guard let self = self else { return }

                Task { @MainActor in
                    await self.handleIncomingMessage(snapshot)
                }
            }, withCancel: { [weak self] error in
                guard let self = self else { return }
                Task { @MainActor in
                    self.error = error
                    print("❌ RTDB Error (childAdded): \(error.localizedDescription)")
                }
            })

        // Listen for message status updates
        childChangedHandle = messagesRef.observe(.childChanged, with: { [weak self] snapshot in
            guard let self = self else { return }

            Task { @MainActor in
                await self.handleMessageUpdate(snapshot)
            }
        }, withCancel: { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                self.error = error
                print("❌ RTDB Error (childChanged): \(error.localizedDescription)")
            }
        })
    }

    /// Stops real-time listener and cleans up
    func stopRealtimeListener() {
        if let handle = childAddedHandle {
            messagesRef.removeObserver(withHandle: handle)
        }
        if let handle = childChangedHandle {
            messagesRef.removeObserver(withHandle: handle)
        }
        childAddedHandle = nil
        childChangedHandle = nil
    }

    /// Marks all unread messages in conversation as read
    func markAsRead() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("⚠️ [READ-RECEIPT] No authenticated user")
            return
        }

        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.conversationID == conversationID &&
                message.senderID != currentUserID
            }
        )

        guard let fetchedMessages = try? modelContext.fetch(descriptor) else {
            print("⚠️ [READ-RECEIPT] Failed to fetch messages")
            return
        }

        // Filter for unread messages
        let messages = fetchedMessages.filter { $0.status != .read }

        print("📖 [READ-RECEIPT] Marking \(messages.count) messages as read in conversation: \(conversationID)")

        for message in messages {
            print("  ✓ [READ-RECEIPT] Marking message \(message.id) as read (was: \(message.status.rawValue))")
            message.status = .read

            // Update RTDB
            Task { @MainActor in
                do {
                    try await messagesRef.child(message.id).updateChildValues([
                        "status": "read"
                    ])
                    print("  ✅ [READ-RECEIPT] Updated RTDB for message \(message.id)")
                } catch {
                    print("  ❌ [READ-RECEIPT] Failed to update RTDB for message \(message.id): \(error.localizedDescription)")
                }
            }
        }

        try? modelContext.save()
    }

    /// Retry sending a failed message
    func retryFailedMessage(_ message: MessageEntity) async {
        // Reset sync status to pending
        message.syncStatus = .pending
        message.retryCount = 0
        message.syncError = nil
        message.lastSyncAttempt = Date()
        try? modelContext.save()

        // Re-attempt sync to RTDB
        do {
            let messageData: [String: Any] = [
                "senderID": message.senderID,
                "text": message.text,
                "serverTimestamp": ServerValue.timestamp(),
                "status": message.status.rawValue
            ]

            try await messagesRef.child(message.id).setValue(messageData)

            // Mark as synced
            message.syncStatus = .synced
            try? modelContext.save()

            // Update conversation last message
            await updateConversationLastMessage(text: message.text)

        } catch {
            // Mark as failed again
            message.syncStatus = .failed
            message.syncError = error.localizedDescription
            message.retryCount += 1
            self.error = error
            try? modelContext.save()
        }
    }

    // MARK: - Private Methods

    private func handleIncomingMessage(_ snapshot: DataSnapshot) async {
        guard let messageData = snapshot.value as? [String: Any] else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let messageID = snapshot.key
        let senderID = messageData["senderID"] as? String ?? ""

        // Check if message already exists locally (duplicate detection)
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        let existing = try? modelContext.fetch(descriptor).first

        if existing == nil {
            // New message from RTDB
            // Firebase RTDB timestamp is in milliseconds, Date expects seconds
            let serverTimestampMs = messageData["serverTimestamp"] as? Double ?? 0
            let serverTimestamp = serverTimestampMs > 0 ? Date(timeIntervalSince1970: serverTimestampMs / 1000.0) : nil

            // Determine initial status
            // - If from current user: use RTDB status (sent/delivered/read)
            // - If from another user: mark as delivered (we just received it)
            let isFromCurrentUser = senderID == currentUserID
            let rtdbStatus = MessageStatus(rawValue: messageData["status"] as? String ?? "sent") ?? .sent
            let initialStatus: MessageStatus = isFromCurrentUser ? rtdbStatus : .delivered

            let message = MessageEntity(
                id: messageID,
                conversationID: conversationID,
                senderID: senderID,
                text: messageData["text"] as? String ?? "",
                localCreatedAt: serverTimestamp ?? Date(), // Use server timestamp if available
                serverTimestamp: serverTimestamp,
                sequenceNumber: messageData["sequenceNumber"] as? Int64,
                status: initialStatus,
                syncStatus: .synced
            )

            modelContext.insert(message)
            try? modelContext.save()

            // If this is someone else's message, mark it as delivered in RTDB
            if !isFromCurrentUser {
                Task { @MainActor in
                    try? await messagesRef.child(messageID).updateChildValues([
                        "status": "delivered"
                    ])
                }

                // Trigger in-app notification for new message
                await triggerNotificationForMessage(
                    messageID: messageID,
                    senderID: senderID,
                    text: messageData["text"] as? String ?? ""
                )
            }
        } else if let existingMessage = existing {
            // Update existing message if it was pending (our own message synced)
            if existingMessage.syncStatus == .pending {
                // Firebase RTDB timestamp is in milliseconds, Date expects seconds
                let serverTimestampMs = messageData["serverTimestamp"] as? Double ?? 0
                if serverTimestampMs > 0 {
                    existingMessage.serverTimestamp = Date(timeIntervalSince1970: serverTimestampMs / 1000.0)
                }
                existingMessage.sequenceNumber = messageData["sequenceNumber"] as? Int64
                existingMessage.syncStatus = .synced
                try? modelContext.save()
            }
        }
    }

    private func handleMessageUpdate(_ snapshot: DataSnapshot) async {
        guard let messageData = snapshot.value as? [String: Any] else { return }

        let messageID = snapshot.key

        print("🔄 [MESSAGE-UPDATE] Received update for message: \(messageID)")
        print("   Status: \(messageData["status"] as? String ?? "nil")")

        // Find existing message
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        guard let existing = try? modelContext.fetch(descriptor).first else {
            print("   ⚠️ [MESSAGE-UPDATE] Message not found locally")
            return
        }

        print("   Current local status: \(existing.status.rawValue)")

        // Update status (delivered → read)
        if let statusString = messageData["status"] as? String,
           let status = MessageStatus(rawValue: statusString) {
            print("   ✅ [MESSAGE-UPDATE] Updating status: \(existing.status.rawValue) → \(status.rawValue)")
            existing.status = status
            try? modelContext.save()
        }
    }

    private func updateConversationLastMessage(text: String) async {
        let conversationRef = Database.database().reference().child("conversations/\(conversationID)")

        try? await conversationRef.updateChildValues([
            "lastMessage": text,
            "lastMessageTimestamp": ServerValue.timestamp()
        ])
    }

    /// Triggers in-app notification when new message arrives from another user
    private func triggerNotificationForMessage(
        messageID: String,
        senderID: String,
        text: String
    ) async {
        // Fetch sender's name from Firestore
        let senderName = await fetchSenderName(senderID: senderID)

        // Trigger in-app notification banner (works on simulator)
        await NotificationService.shared.showInAppNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )

        // Also schedule local notification for background (works on simulator)
        await NotificationService.shared.scheduleLocalNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )
    }

    /// Fetches sender display name from Firestore
    private func fetchSenderName(senderID: String) async -> String {
        do {
            let db = FirebaseFirestore.Firestore.firestore()
            let doc = try await db.collection("users").document(senderID).getDocument()
            return doc.data()?["displayName"] as? String ?? "Unknown User"
        } catch {
            return "Unknown User"
        }
    }

}
