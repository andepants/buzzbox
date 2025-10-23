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

    /// Tracks if we're in the initial load phase vs real-time updates
    /// Initial load: fetching last 100 messages when listener starts
    /// Real-time: new messages arriving after initial load completes
    private var isInitialLoad = true

    /// Counter to track initial load progress
    private var initialLoadMessageCount = 0

    /// Timestamp when listener started (used to determine if message is "new")
    private var listenerStartTime: Date?

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
            return
        }

        // Determine if this is a DM and who the recipient is
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )
        
        if let conversation = try? modelContext.fetch(descriptor).first {
            
            if !conversation.isGroup {
                // This is a DM - find the other participant
                let participants = conversation.participantIDs
                if let recipientID = participants.first(where: { $0 != currentUserID }) {
                } else {
                }
            }
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
                    "status": "delivered" // Mark as delivered once RTDB confirms storage
                ]

                try await messagesRef.child(messageID).setValue(messageData)

                // Update local sync status and mark as delivered (RTDB confirmed)
                message.syncStatus = .synced
                message.status = .delivered
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
        // Reset listener state for initial load
        isInitialLoad = true
        initialLoadMessageCount = 0
        listenerStartTime = Date()


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
            }
        })

        // Wait a short time for initial batch to complete
        // Firebase fires .childAdded for all existing children rapidly, then continues with real-time updates
        // After 2 seconds of no activity, we assume initial load is complete
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if self.isInitialLoad {
                self.isInitialLoad = false
            }
        }
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

        // Reset listener state
        isInitialLoad = true
        initialLoadMessageCount = 0
        listenerStartTime = nil

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
                "status": "delivered" // Mark as delivered once RTDB confirms storage
            ]

            try await messagesRef.child(message.id).setValue(messageData)

            // Mark as synced and delivered (RTDB confirmed)
            message.syncStatus = .synced
            message.status = .delivered
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

        // Track initial load progress
        if isInitialLoad {
            initialLoadMessageCount += 1
        }

        guard let messageData = snapshot.value as? [String: Any] else {
            return
        }

        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }

        let messageID = snapshot.key
        let senderID = messageData["senderID"] as? String ?? ""
        let messageText = messageData["text"] as? String ?? ""

        // Get message timestamp to determine if it's "new"
        let serverTimestampMs = messageData["serverTimestamp"] as? Double ?? 0
        let messageTimestamp = serverTimestampMs > 0 ? Date(timeIntervalSince1970: serverTimestampMs / 1000.0) : nil


        // Check if message already exists locally (duplicate detection)
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        let existing = try? modelContext.fetch(descriptor).first

        if existing == nil {

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
                text: messageText,
                localCreatedAt: messageTimestamp ?? Date(), // Use server timestamp if available
                serverTimestamp: messageTimestamp,
                sequenceNumber: messageData["sequenceNumber"] as? Int64,
                status: initialStatus,
                syncStatus: .synced
            )

            modelContext.insert(message)
            try? modelContext.save()

            // Determine if we should trigger notification
            let shouldTriggerNotification = !isFromCurrentUser && !isInitialLoad


            if shouldTriggerNotification {

                // Trigger in-app notification for new message
                await triggerNotificationForMessage(
                    messageID: messageID,
                    senderID: senderID,
                    text: messageText
                )
            } else if isFromCurrentUser {
            } else if isInitialLoad {
            }
        } else {

            if let existingMessage = existing {
                // Update existing message if it was pending (our own message synced)
                if existingMessage.syncStatus == .pending {
                    if serverTimestampMs > 0 {
                        existingMessage.serverTimestamp = Date(timeIntervalSince1970: serverTimestampMs / 1000.0)
                    }
                    existingMessage.sequenceNumber = messageData["sequenceNumber"] as? Int64
                    existingMessage.syncStatus = .synced
                    try? modelContext.save()
                }
            }
        }
    }

    private func handleMessageUpdate(_ snapshot: DataSnapshot) async {
        guard let messageData = snapshot.value as? [String: Any] else { return }

        let messageID = snapshot.key


        // Find existing message
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.id == messageID }
        )

        guard let existing = try? modelContext.fetch(descriptor).first else {
            return
        }


        // Update status (delivered → read)
        if let statusString = messageData["status"] as? String,
           let status = MessageStatus(rawValue: statusString) {
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
    /// Triggers in-app notification when new message arrives from another user
    private func triggerNotificationForMessage(
        messageID: String,
        senderID: String,
        text: String
    ) async {
        
        // Get current user info
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Determine user roles
        let isCurrentUserCreator = currentUserID == "andrewsheim@gmail.com" // Your creator email
        let isSenderCreator = senderID == "andrewsheim@gmail.com"

        // Fetch sender's name from Firestore
        let senderName = await fetchSenderName(senderID: senderID)

        // ═══════════════════════════════════════════════════════════
        // TRIGGER IN-APP NOTIFICATION (Foreground banner)
        // ═══════════════════════════════════════════════════════════
        
        do {
            await NotificationService.shared.showInAppNotification(
                title: senderName,
                body: text,
                conversationID: conversationID
            )
        } catch {
        }

        // ═══════════════════════════════════════════════════════════
        // TRIGGER LOCAL NOTIFICATION (Background/Foreground)
        // ═══════════════════════════════════════════════════════════
        
        do {
            await NotificationService.shared.scheduleLocalNotification(
                title: senderName,
                body: text,
                conversationID: conversationID
            )
        } catch {
        }

        
        // Note: FCM push notification will be sent by Cloud Function
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
