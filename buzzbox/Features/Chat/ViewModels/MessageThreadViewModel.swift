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
            print("❌ [MESSAGE SEND] Failed: No authenticated user")
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        print("📤 [MESSAGE SEND] Starting message send")
        print("    └─ ConversationID: \(conversationID)")
        print("    └─ SenderID: \(currentUserID)")
        print("    └─ MessageLength: \(text.count) characters")
        print("    └─ Timestamp: \(timestamp)")

        // Determine if this is a DM and who the recipient is
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )

        var recipientID: String?
        var isGroupChat = false
        var isMessageToCreator = false

        if let conversation = try? modelContext.fetch(descriptor).first {
            isGroupChat = conversation.isGroup

            if !conversation.isGroup {
                // This is a DM - find the other participant
                let participants = conversation.participantIDs
                recipientID = participants.first(where: { $0 != currentUserID })

                if let recipientID = recipientID {
                    print("    └─ MessageType: Direct Message (DM)")
                    print("    └─ RecipientID: \(recipientID)")

                    // Check if recipient is the creator by fetching their email
                    let recipientDescriptor = FetchDescriptor<UserEntity>(
                        predicate: #Predicate { $0.id == recipientID }
                    )
                    if let recipient = try? modelContext.fetch(recipientDescriptor).first {
                        isMessageToCreator = recipient.email.lowercased() == CREATOR_EMAIL.lowercased()

                        // FAQ TRIGGER DETECTION LOGGING
                        if isMessageToCreator {
                            print("🤖 [FAQ CHECK] Message TO creator detected")
                            print("    └─ RecipientEmail: \(recipient.email)")
                            print("    └─ ShouldTriggerFAQ: YES (DM to creator)")
                            print("    └─ ExpectedBehavior: Cloud Function will check FAQ database")
                            print("    └─ MessageText: \(text)")
                        } else {
                            print("ℹ️ [FAQ CHECK] Message NOT to creator")
                            print("    └─ RecipientEmail: \(recipient.email)")
                            print("    └─ ShouldTriggerFAQ: NO (not DM to creator)")
                        }
                    }
                } else {
                    print("    └─ ⚠️ Warning: Could not identify recipient")
                }
            } else {
                print("    └─ MessageType: Group Chat")
                print("    └─ Participants: \(conversation.participantIDs.count)")
                print("ℹ️ [FAQ CHECK] ShouldTriggerFAQ: NO (group chat, not 1:1 DM)")
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
            let syncStartTime = Date()

            do {

                // Push to RTDB (generates server timestamp)
                let messageData: [String: Any] = [
                    "senderID": message.senderID,
                    "text": message.text,
                    "serverTimestamp": ServerValue.timestamp(),
                    "status": "delivered" // Mark as delivered once RTDB confirms storage
                ]

                let rtdbPath = "/messages/\(conversationID)/\(messageID)"
                print("📤 [RTDB WRITE] Writing message to Firebase RTDB...")
                print("    └─ Path: \(rtdbPath)")
                print("    └─ Data: senderID, text, serverTimestamp, status")
                print("    └─ This should trigger: onMessageCreated Cloud Function")

                try await messagesRef.child(messageID).setValue(messageData)

                let syncDuration = Date().timeIntervalSince(syncStartTime)

                print("✅ [RTDB SYNC] Message synced successfully")
                print("    └─ MessageID: \(messageID)")
                print("    └─ ConversationID: \(conversationID)")
                print("    └─ SyncDuration: \(String(format: "%.2f", syncDuration))s")
                print("    └─ Status: delivered")

                // FAQ expectation logging
                if isMessageToCreator && !isGroupChat {
                    print("🤖 [FAQ EXPECTATION] Cloud Function should now:")
                    print("    └─ 1. Detect this is a DM to creator")
                    print("    └─ 2. Check message against FAQ database via OpenAI")
                    print("    └─ 3. Send FAQ auto-response if match found")
                    print("    └─ 4. Response will appear as incoming message with isFAQResponse flag")
                    print("    └─ ⏱️ Expected response time: 2-5 seconds")
                }

                // Update local sync status and mark as delivered (RTDB confirmed)
                message.syncStatus = .synced
                message.status = .delivered
                try? modelContext.save()

                // Store Q&A pair in Supermemory (Story 9.2 - RAG Integration)
                await storeReplyInSupermemory(andrewReply: text, conversationID: conversationID)

                // Update conversation last message
                await updateConversationLastMessage(text: text)

                // Log recipient notification status (for DMs only)
                if let recipientID = recipientID, !isGroupChat {
                    await logRecipientNotificationStatus(
                        recipientID: recipientID,
                        messageID: messageID,
                        conversationID: conversationID
                    )
                }

            } catch {

                print("❌ [RTDB SYNC] Message sync failed")
                print("    └─ MessageID: \(messageID)")
                print("    └─ ConversationID: \(conversationID)")
                print("    └─ Error: \(error.localizedDescription)")

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

        // Note: We use timestamp comparison (messageTimestamp > listenerStartTime) to determine
        // if a message is new vs historical, so no delay is needed here.
        // Historical messages are automatically filtered in handleIncomingMessage().
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

    /// Logs comprehensive notification status for recipient (sender-side perspective)
    /// This shows the sender what notification delivery to expect for the recipient
    private func logRecipientNotificationStatus(
        recipientID: String,
        messageID: String,
        conversationID: String
    ) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        print("📬 [RECIPIENT NOTIF] Notification will be sent to recipient")
        print("    └─ RecipientID: \(recipientID)")
        print("    └─ MessageID: \(messageID)")
        print("    └─ ConversationID: \(conversationID)")

        // Fetch recipient name from Firestore
        let recipientName = await fetchSenderName(senderID: recipientID)
        print("    └─ RecipientName: \(recipientName)")

        // Check recipient's online status from RTDB presence
        let recipientStatus = await checkRecipientPresence(recipientID: recipientID)
        print("    └─ RecipientStatus: \(recipientStatus.isOnline ? "online" : "offline")")

        if let lastSeen = recipientStatus.lastSeen {
            let timeAgo = Date().timeIntervalSince(lastSeen)
            let lastSeenString: String
            if timeAgo < 60 {
                lastSeenString = "just now"
            } else if timeAgo < 3600 {
                lastSeenString = "\(Int(timeAgo / 60))m ago"
            } else if timeAgo < 86400 {
                lastSeenString = "\(Int(timeAgo / 3600))h ago"
            } else {
                lastSeenString = "\(Int(timeAgo / 86400))d ago"
            }
            print("    └─ LastSeen: \(lastSeenString)")
        }

        // Check if recipient is viewing this conversation
        let recipientCurrentScreen = await checkRecipientCurrentScreen(recipientID: recipientID)
        let isViewingConversation = recipientCurrentScreen == conversationID

        if isViewingConversation {
            print("    └─ RecipientScreen: viewing THIS conversation")
        } else if let screen = recipientCurrentScreen {
            print("    └─ RecipientScreen: viewing different conversation (\(screen))")
        } else {
            print("    └─ RecipientScreen: not in any conversation")
        }

        // Determine notification methods
        #if targetEnvironment(simulator)
        let notificationMethods = "in-app banner, local notification (FCM unavailable on simulator)"
        #else
        let notificationMethods = "in-app banner, local notification, FCM push"
        #endif
        print("    └─ NotificationMethods: \(notificationMethods)")

        // Determine expected delivery timing
        let expectedDelivery: String
        if recipientStatus.isOnline {
            if isViewingConversation {
                expectedDelivery = "immediate (user viewing conversation)"
            } else {
                expectedDelivery = "immediate (user online)"
            }
        } else {
            expectedDelivery = "on app open / device unlock"
        }
        print("    └─ ExpectedDelivery: \(expectedDelivery)")
        print("    └─ Timestamp: \(timestamp)")
    }

    /// Checks recipient's presence status in RTDB
    private func checkRecipientPresence(recipientID: String) async -> (isOnline: Bool, lastSeen: Date?) {
        do {
            let presenceRef = Database.database().reference().child("userPresence/\(recipientID)")
            let snapshot = try await presenceRef.getData()

            let isOnline = snapshot.childSnapshot(forPath: "online").value as? Bool ?? false
            let lastSeenTimestamp = snapshot.childSnapshot(forPath: "lastSeen").value as? TimeInterval ?? 0

            let lastSeen: Date? = lastSeenTimestamp > 0 ? Date(timeIntervalSince1970: lastSeenTimestamp / 1000) : nil

            return (isOnline, lastSeen)
        } catch {
            // Silent failure - presence check is non-critical
            return (false, nil)
        }
    }

    /// Checks what screen/conversation recipient is currently viewing
    private func checkRecipientCurrentScreen(recipientID: String) async -> String? {
        do {
            let presenceRef = Database.database().reference().child("userPresence/\(recipientID)")
            let snapshot = try await presenceRef.getData()

            return snapshot.childSnapshot(forPath: "currentConversationID").value as? String
        } catch {
            // Silent failure - screen check is non-critical
            return nil
        }
    }

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

            // Sync AI-related properties from RTDB
            message.isAIGenerated = messageData["isAIGenerated"] as? Bool ?? false
            message.isFAQResponse = messageData["isFAQResponse"] as? Bool ?? false

            // FAQ RESPONSE DETECTION LOGGING
            if message.isFAQResponse {
                print("🎉 [FAQ RESPONSE] FAQ auto-response received from Cloud Function!")
                print("    └─ MessageID: \(messageID)")
                print("    └─ SenderID: \(senderID) (should be creator)")
                print("    └─ IsAIGenerated: \(message.isAIGenerated)")
                print("    └─ IsFAQResponse: \(message.isFAQResponse)")
                print("    └─ ResponseText: \(messageText)")
                print("    └─ TextLength: \(messageText.count) characters")
                print("    └─ FAQ Badge: Will be displayed in UI")
                print("    └─ ✅ FAQ auto-response system is working!")
            } else if message.isAIGenerated {
                print("🤖 [AI MESSAGE] AI-generated message received")
                print("    └─ MessageID: \(messageID)")
                print("    └─ IsAIGenerated: true")
                print("    └─ IsFAQResponse: false (other AI feature)")
            }

            modelContext.insert(message)
            try? modelContext.save()

            // Update conversation with new message (increments messageCountSinceAnalysis)
            let convDescriptor = FetchDescriptor<ConversationEntity>(
                predicate: #Predicate { $0.id == conversationID }
            )
            if let conversation = try? modelContext.fetch(convDescriptor).first {
                conversation.updateWithMessage(message)
                try? modelContext.save()
            }

            // Determine if message is historical using timestamp comparison
            // Historical = message was sent BEFORE listener started
            // New = message was sent AFTER listener started
            let isHistoricalMessage: Bool
            if let messageTimestamp = messageTimestamp, let listenerStartTime = listenerStartTime {
                // Message is historical if it was sent BEFORE listener started
                isHistoricalMessage = messageTimestamp <= listenerStartTime
            } else {
                // If no timestamp available, assume historical (safer default to avoid spam)
                isHistoricalMessage = true
            }

            // Log message receipt for debugging
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logPrefix = isFromCurrentUser ? "📤 [MESSAGE] [OUTGOING]" : "📥 [MESSAGE] [INCOMING]"

            print("\(logPrefix) Message received in thread view")
            print("    └─ MessageID: \(messageID)")
            print("    └─ SenderID: \(senderID)")
            print("    └─ ConversationID: \(conversationID)")
            print("    └─ IsAIGenerated: \(message.isAIGenerated)")
            print("    └─ IsFAQResponse: \(message.isFAQResponse)")

            // Log timestamp comparison details
            if let messageTimestamp = messageTimestamp {
                print("    └─ MessageTimestamp: \(ISO8601DateFormatter().string(from: messageTimestamp))")
            } else {
                print("    └─ MessageTimestamp: nil")
            }

            if let listenerStartTime = listenerStartTime {
                print("    └─ ListenerStartTime: \(ISO8601DateFormatter().string(from: listenerStartTime))")
            } else {
                print("    └─ ListenerStartTime: nil")
            }

            print("    └─ IsHistoricalMessage: \(isHistoricalMessage)")
            print("    └─ IsFromCurrentUser: \(isFromCurrentUser)")

            // If this is someone else's message and not historical, trigger notification
            if !isFromCurrentUser && !isHistoricalMessage {
                print("    └─ 🔔 Triggering notification...")

                // Mark as delivered in RTDB
                Task { @MainActor in
                    try? await messagesRef.child(messageID).updateChildValues([
                        "status": "delivered"
                    ])
                }

                // Trigger notification
                await triggerNotificationForMessage(
                    messageID: messageID,
                    senderID: senderID,
                    text: messageText,
                    conversationID: conversationID
                )

                // FAQ Auto-Response is now handled server-side in Cloud Functions
                // See: functions/src/index.ts -> onMessageCreated
                // No client-side FAQ checking needed anymore
            } else {
                if isFromCurrentUser {
                    print("    └─ ⏭️  Skipped: Message from current user (no self-notification)")
                } else if isHistoricalMessage {
                    print("    └─ ⏭️  Skipped: Historical message (listener backfill)")
                }
            }

            print("    └─ Timestamp: \(timestamp)")
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

            // Log status change with detailed info
            let oldStatus = existing.status
            let timestamp = ISO8601DateFormatter().string(from: Date())

            print("📨 [MESSAGE STATUS] Status updated")
            print("    └─ MessageID: \(messageID)")
            print("    └─ ConversationID: \(conversationID)")
            print("    └─ OldStatus: \(oldStatus.rawValue)")
            print("    └─ NewStatus: \(status.rawValue)")
            print("    └─ StatusChange: \(oldStatus.rawValue) → \(status.rawValue)")
            print("    └─ Timestamp: \(timestamp)")

            existing.status = status
            try? modelContext.save()
        }

        // Update AI metadata if present (Story 6.2: Auto-processing)
        var aiMetadataUpdated = false

        if let aiCategoryString = messageData["aiCategory"] as? String,
           let category = MessageCategory(rawValue: aiCategoryString) {
            existing.category = category
            aiMetadataUpdated = true
        }

        if let aiSentimentString = messageData["aiSentiment"] as? String,
           let sentiment = MessageSentiment(rawValue: aiSentimentString) {
            existing.sentiment = sentiment
            aiMetadataUpdated = true
        }

        if let aiOpportunityScore = messageData["aiOpportunityScore"] as? Int {
            existing.opportunityScore = aiOpportunityScore
            aiMetadataUpdated = true
        }

        if let aiProcessedAtMs = messageData["aiProcessedAt"] as? Double {
            existing.aiProcessedAt = Date(timeIntervalSince1970: aiProcessedAtMs / 1000.0)
            aiMetadataUpdated = true
        }

        if let isAIGenerated = messageData["isAIGenerated"] as? Bool {
            existing.isAIGenerated = isAIGenerated
            aiMetadataUpdated = true
        }

        if let isFAQResponse = messageData["isFAQResponse"] as? Bool {
            existing.isFAQResponse = isFAQResponse
            aiMetadataUpdated = true
        }

        if aiMetadataUpdated {
            print("🤖 [AI METADATA] Message updated with AI metadata")
            print("    └─ MessageID: \(messageID)")
            print("    └─ Category: \(existing.category?.rawValue ?? "nil")")
            print("    └─ Sentiment: \(existing.sentiment?.rawValue ?? "nil")")
            print("    └─ OpportunityScore: \(existing.opportunityScore.map(String.init) ?? "nil")")
            try? modelContext.save()
        }

        // Update smart replies cache if present (Story 6.10: Smart Replies Caching)
        if let smartRepliesData = messageData["smartReplies"] as? [String: Any] {
            var smartRepliesUpdated = false

            if let short = smartRepliesData["short"] as? String {
                existing.smartReplyShort = short
                smartRepliesUpdated = true
            }

            if let medium = smartRepliesData["medium"] as? String {
                existing.smartReplyMedium = medium
                smartRepliesUpdated = true
            }

            if let detailed = smartRepliesData["detailed"] as? String {
                existing.smartReplyDetailed = detailed
                smartRepliesUpdated = true
            }

            if let generatedAtMs = smartRepliesData["generatedAt"] as? Double {
                existing.smartRepliesGeneratedAt = Date(timeIntervalSince1970: generatedAtMs / 1000.0)
                smartRepliesUpdated = true
            }

            if smartRepliesUpdated {
                print("💬 [SMART REPLIES] Message updated with cached smart replies")
                print("    └─ MessageID: \(messageID)")
                print("    └─ Short: \(existing.smartReplyShort != nil ? "✅" : "❌")")
                print("    └─ Medium: \(existing.smartReplyMedium != nil ? "✅" : "❌")")
                print("    └─ Detailed: \(existing.smartReplyDetailed != nil ? "✅" : "❌")")
                try? modelContext.save()
            }
        }
    }

    private func updateConversationLastMessage(text: String) async {
        let conversationRef = Database.database().reference().child("conversations/\(conversationID)")

        try? await conversationRef.updateChildValues([
            "lastMessage": text,
            "lastMessageTimestamp": ServerValue.timestamp(),
            "updatedAt": ServerValue.timestamp()
        ])
    }

    /// Triggers notification for a new message
    private func triggerNotificationForMessage(
        messageID: String,
        senderID: String,
        text: String,
        conversationID: String
    ) async {
        // Fetch sender's name from Firestore
        let senderName = await fetchSenderName(senderID: senderID)

        print("🔔 [MESSAGE THREAD] Triggering notifications")
        print("    └─ Sender: \(senderName)")
        print("    └─ MessageID: \(messageID)")
        print("    └─ ConversationID: \(conversationID)")

        // ═══════════════════════════════════════════════════════════
        // TRIGGER IN-APP NOTIFICATION (Foreground banner)
        // ═══════════════════════════════════════════════════════════
        await NotificationService.shared.showInAppNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )

        // ═══════════════════════════════════════════════════════════
        // TRIGGER LOCAL NOTIFICATION (Background/Foreground)
        // ═══════════════════════════════════════════════════════════
        await NotificationService.shared.scheduleLocalNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )

        print("✅ [MESSAGE THREAD] Notifications triggered successfully")
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

    // MARK: - Supermemory Integration

    /// Stores Andrew's manual reply as a Q&A pair in Supermemory
    /// Fire-and-forget pattern: doesn't block message sending
    /// [Source: Story 9.2 - Memory Storage on Manual Replies]
    private func storeReplyInSupermemory(andrewReply: String, conversationID: String) async {
        // Only for creator replies
        guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
        guard currentUserEmail.lowercased() == CREATOR_EMAIL.lowercased() else { return }

        // Only if Supermemory is enabled
        guard SupermemoryService.shared.isEnabled else { return }

        // Validate inputs
        guard !andrewReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Get last fan message
        guard let fanMessage = getLastFanMessage() else {
            print("⚠️ [SUPERMEMORY] No fan message found to create Q&A pair")
            return
        }

        // Format Q&A pair
        let qaPair = """
        Q: \(fanMessage.text)
        A: \(andrewReply)
        """

        // Get conversation metadata
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == conversationID }
        )
        let conversation = try? modelContext.fetch(descriptor).first

        // Build metadata
        let metadata: [String: String] = [
            "conversationID": conversationID,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "category": conversation?.aiCategory ?? "unknown",
            "platform": "ios",
            "creator": "andrew"
        ]

        // Store in background (fire-and-forget)
        Task.detached(priority: .background) {
            do {
                try await SupermemoryService.shared.addMemory(
                    content: qaPair,
                    metadata: metadata
                )
                print("✅ [SUPERMEMORY] Stored reply as Q&A pair")
            } catch {
                print("⚠️ [SUPERMEMORY] Failed to store reply: \(error.localizedDescription)")
                // Don't propagate error - graceful degradation
            }
        }
    }

    /// Gets the most recent message from a fan (non-creator)
    private func getLastFanMessage() -> MessageEntity? {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return nil }

        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { message in
                message.conversationID == conversationID &&
                message.senderID != currentUserID
            },
            sortBy: [SortDescriptor(\.localCreatedAt, order: .reverse)]
        )

        let messages = try? modelContext.fetch(descriptor)
        return messages?.first
    }

    // MARK: - FAQ Auto-Response

    // FAQ Auto-Response is now handled server-side in Cloud Functions
    // See: functions/src/index.ts -> onMessageCreated
    // When a user sends a message to the creator, the Cloud Function automatically:
    // 1. Checks if it matches an FAQ using GPT-4o-mini
    // 2. Sends an auto-response from the creator if it matches
    // This works even when the creator is offline, providing instant responses 24/7

}
