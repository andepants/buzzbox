/// MessageThreadView.swift
///
/// Main view for message thread with real-time messaging.
/// Features optimistic UI, scroll-to-bottom, keyboard handling, and VoiceOver support.
///
/// Created: 2025-10-21
/// [Source: Story 2.3 - Send and Receive Messages, RTDB Code Examples lines 767-900]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase

/// Message thread view with real-time updates
struct MessageThreadView: View {
    // MARK: - Properties

    let conversation: ConversationEntity

    @Environment(\.modelContext) private var modelContext

    // Query messages for this conversation sorted by timestamps
    @Query private var messages: [MessageEntity]

    @State private var viewModel: MessageThreadViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var recipientDisplayName: String = "Loading..."

    // Typing indicator state
    @State private var typingUserIDs: Set<String> = []
    @State private var typingListenerHandle: DatabaseHandle?
    @State private var participants: [UserEntity] = []

    // Presence status state
    @State private var presenceStatus: PresenceStatus?
    @State private var presenceHandle: DatabaseHandle?

    // Group info state
    @State private var showGroupInfo = false

    // Read receipt listener
    @State private var readReceiptListenerHandle: DatabaseHandle?

    // Channel permission state
    @State private var canPost: Bool = true

    // MARK: - Initialization

    init(conversation: ConversationEntity) {
        self.conversation = conversation

        // Query messages for this conversation
        let conversationID = conversation.id
        _messages = Query(
            filter: #Predicate<MessageEntity> { message in
                message.conversationID == conversationID
            },
            sort: [
                // ✅ Sort by localCreatedAt first (never nil)
                // See Pattern 4 in Epic 2: Null-Safe Sorting
                SortDescriptor(\MessageEntity.localCreatedAt, order: .forward),
                SortDescriptor(\MessageEntity.serverTimestamp, order: .forward),
                SortDescriptor(\MessageEntity.sequenceNumber, order: .forward)
            ]
        )

        // Initialize ViewModel
        let context = ModelContext(AppContainer.shared.modelContainer)
        _viewModel = State(wrappedValue: MessageThreadViewModel(
            conversationID: conversationID,
            modelContext: context
        ))
    }

    // MARK: - Computed Properties

    /// Format typing indicator text for group conversations
    /// [Source: Story 3.5 - Group Typing Indicators, lines 415-430]
    private var typingText: String {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return "" }

        // Filter out current user (don't show own typing)
        let otherTypingUserIDs = typingUserIDs.filter { $0 != currentUserID }

        // Filter by current participants only (exclude removed users)
        let validTypingUserIDs = otherTypingUserIDs.filter {
            conversation.participantIDs.contains($0)
        }

        // Format typing text using service
        return TypingIndicatorService.shared.formatTypingText(
            userIDs: validTypingUserIDs,
            participants: participants
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Network status banner
            if !networkMonitor.isConnected {
                NetworkStatusBanner()
            }

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                conversation: conversation,
                                participants: participants,
                                onRetry: { failedMessage in
                                    Task {
                                        await viewModel.retryFailedMessage(failedMessage)
                                    }
                                }
                            )
                            .id(message.id)
                        }

                        // Typing indicator at bottom
                        // [Source: Story 3.5 - Group Typing Indicators, lines 437-447]
                        if !typingText.isEmpty {
                            HStack {
                                Text(typingText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .italic()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .transition(.opacity)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                    isInputFocused = true // Auto-focus keyboard
                }
                .onChange(of: messages.count) { oldCount, newCount in
                    scrollToBottom(proxy: proxy)

                    // VoiceOver announcement for new messages
                    if newCount > oldCount, let newMessage = messages.last {
                        if newMessage.senderID != Auth.auth().currentUser?.uid {
                            UIAccessibility.post(
                                notification: .announcement,
                                argument: "New message: \(newMessage.text)"
                            )
                        }
                    }
                }
            }

            // Message input composer or read-only banner
            if canPost {
                MessageComposerView(
                    text: $messageText,
                    characterLimit: 10_000,
                    onSend: {
                        await sendMessage()
                    }
                )
                .focused($isInputFocused)
                .onChange(of: messageText) { oldValue, newValue in
                    handleTypingChange(newValue)
                }
            } else {
                // Read-only banner for creator-only channels
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Only Andrew can post here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
            }
        }
        .navigationTitle(recipientDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    if conversation.isGroup {
                        showGroupInfo = true
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(recipientDisplayName)
                            .font(.headline)

                        // ✅ Group participant count or presence status
                        if conversation.isGroup {
                            Text("\(conversation.participantIDs.count) participants")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let status = presenceStatus {
                            // [Source: Story 2.8 - User Presence & Online Status]
                            Text(status.displayText)
                                .font(.caption)
                                .foregroundStyle(status.isOnline ? .green : .secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            NavigationStack {
                GroupInfoView(conversation: conversation)
            }
        }
        .task {
            print("📱 [THREAD] MessageThreadView opened for: \(conversation.displayName ?? conversation.id)")
            print("  🔐 Initial isCreatorOnly state: \(conversation.isCreatorOnly)")

            // Notify NotificationService that user is viewing this conversation
            // (prevents duplicate in-app notifications for this conversation)
            NotificationService.shared.setCurrentConversation(conversation.id)

            // Check creator-only posting permission
            await checkPostingPermission()

            // Load participants for typing indicator display
            await loadParticipants()

            // Start typing listener
            typingListenerHandle = TypingIndicatorService.shared.listenToTypingIndicators(
                conversationID: conversation.id
            ) { userIDs in
                withAnimation {
                    typingUserIDs = userIDs.filter { $0 != Auth.auth().currentUser?.uid }
                }
            }

            // Start presence listener
            await startPresenceListener()

            // Start read receipt listener
            startReadReceiptListener()

            // Mark all visible messages as read
            await markVisibleMessagesAsRead()

            await loadRecipientName()
            await viewModel.startRealtimeListener()
            await viewModel.markAsRead()
        }
        .onDisappear {
            // Clear current conversation tracking for notifications
            NotificationService.shared.setCurrentConversation(nil)

            // Cleanup: Stop typing
            if let currentUserID = Auth.auth().currentUser?.uid {
                TypingIndicatorService.shared.stopTyping(
                    conversationID: conversation.id,
                    userID: currentUserID
                )
            }

            // Remove typing listener
            if let handle = typingListenerHandle {
                TypingIndicatorService.shared.stopListening(
                    conversationID: conversation.id,
                    handle: handle
                )
            }

            // Stop presence listener
            stopPresenceListener()

            // Stop read receipt listener
            stopReadReceiptListener()

            viewModel.stopRealtimeListener()
        }
    }

    // MARK: - Private Methods

    /// Check if current user can post to this conversation (creator-only channels)
    /// [Source: Story 5.3 - Channel System]
    private func checkPostingPermission() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("❌ [PERMISSION] No authenticated user")
            canPost = false
            return
        }

        print("🔍 [PERMISSION] Checking posting permission for conversation: \(conversation.displayName ?? conversation.id)")
        print("  📋 Conversation ID: \(conversation.id)")
        print("  🔐 isCreatorOnly: \(conversation.isCreatorOnly)")
        print("  👥 isGroup: \(conversation.isGroup)")
        print("  🆔 Current User ID: \(currentUserID)")

        // ✅ DMs: Always allow posting (both participants can message each other)
        if !conversation.isGroup {
            canPost = true
            print("  ✅ canPost result: TRUE (DM - always allowed)")
            return
        }

        // ✅ Channels: Check creator-only restrictions
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.id == currentUserID }
        )

        do {
            let users = try modelContext.fetch(descriptor)
            guard let currentUser = users.first else {
                print("❌ [PERMISSION] User not found in SwiftData")
                canPost = false
                return
            }

            print("  👤 User email: \(currentUser.email)")
            print("  🎭 User type: \(currentUser.userType.rawValue)")
            print("  ⭐ isCreator: \(currentUser.isCreator)")

            canPost = conversation.canUserPost(isCreator: currentUser.isCreator)

            print("  ✅ canPost result: \(canPost)")

            if !canPost {
                print("🔒 [PERMISSION] User cannot post to creator-only channel")
            }
        } catch {
            print("⚠️ [PERMISSION] Failed to check posting permission: \(error.localizedDescription)")
            canPost = false
        }
    }

    /// Load participant entities for typing indicator display
    /// [Source: Story 3.5 - Group Typing Indicators, lines 485-513]
    private func loadParticipants() async {
        let participantIDs = conversation.participantIDs

        // Fetch from SwiftData cache first
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate<UserEntity> { user in
                participantIDs.contains(user.id)
            }
        )

        do {
            participants = try modelContext.fetch(descriptor)

            // Check for missing users not in SwiftData
            let cachedUserIDs = Set(participants.map { $0.id })
            let missingUserIDs = participantIDs.filter { !cachedUserIDs.contains($0) }

            // Fetch missing users from Firestore
            for userID in missingUserIDs {
                if let userData = try? await ConversationService.shared.getUser(userID: userID) {
                    participants.append(userData)
                }
            }
        } catch {
            print("⚠️ Failed to load participants: \(error.localizedDescription)")
        }
    }

    private func sendMessage() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        // ✅ DMs: Always allow sending (both participants can message each other)
        // ✅ Channels: Check creator-only permission
        if conversation.isGroup {
            let descriptor = FetchDescriptor<UserEntity>(
                predicate: #Predicate { $0.id == currentUserID }
            )

            do {
                let users = try modelContext.fetch(descriptor)
                guard let currentUser = users.first else { return }

                // Check if user can post to this conversation
                if !conversation.canUserPost(isCreator: currentUser.isCreator) {
                    // Show error: User cannot post to creator-only channel
                    print("⚠️ User cannot post to creator-only channel")
                    #if os(iOS)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                    return
                }
            } catch {
                print("⚠️ Failed to fetch current user: \(error.localizedDescription)")
                return
            }
        }

        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate message
        do {
            try MessageValidator.validate(trimmed)
        } catch {
            // Show error: Empty or too long
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
            return
        }

        let text = messageText
        messageText = "" // Clear input immediately (optimistic UI)

        // Send message
        await viewModel.sendMessage(text: text)

        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func loadRecipientName() async {
        // For group channels, use the group's display name directly
        if conversation.isGroup {
            recipientDisplayName = conversation.displayName ?? "Group Chat"
            return
        }

        // For DMs, load the recipient's display name
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        // Load recipient user from SwiftData or RTDB
        if let recipientUser = try? await ConversationService.shared.getUser(userID: recipientID) {
            recipientDisplayName = recipientUser.displayName
        }
    }

    private func handleTypingChange(_ text: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            // User is typing
            TypingIndicatorService.shared.startTyping(
                conversationID: conversation.id,
                userID: currentUserID
            )
        } else {
            // User cleared input
            TypingIndicatorService.shared.stopTyping(
                conversationID: conversation.id,
                userID: currentUserID
            )
        }
    }

    // MARK: - Presence Listener Methods

    /// Start listening to recipient's presence status
    /// [Source: Story 2.8 - User Presence & Online Status]
    private func startPresenceListener() async {
        guard !conversation.isGroup else {
            // For groups, show online count instead
            // TODO: Implement group presence in future story
            return
        }

        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        presenceHandle = UserPresenceService.shared.listenToPresence(userID: recipientID) { status in
            presenceStatus = status
        }
    }

    /// Stop listening to presence updates
    /// [Source: Story 2.8 - User Presence & Online Status]
    private func stopPresenceListener() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        UserPresenceService.shared.stopListening(userID: recipientID)
    }

    // MARK: - Read Receipt Methods

    /// Start listening to read receipt updates for this conversation
    /// [Source: Story 3.6 - Group Read Receipts]
    private func startReadReceiptListener() {
        readReceiptListenerHandle = MessageService.shared.listenToReadReceipts(
            conversationID: conversation.id
        ) { [weak modelContext] messageID, readByDates in
            guard let modelContext = modelContext else { return }

            // Update SwiftData with new read receipts
            let descriptor = FetchDescriptor<MessageEntity>(
                predicate: #Predicate<MessageEntity> { msg in
                    msg.id == messageID
                }
            )

            if let message = try? modelContext.fetch(descriptor).first {
                message.readBy = readByDates
                try? modelContext.save()
            }
        }
    }

    /// Stop listening to read receipt updates
    /// [Source: Story 3.6 - Group Read Receipts]
    private func stopReadReceiptListener() {
        guard let handle = readReceiptListenerHandle else { return }
        MessageService.shared.stopListening(conversationID: conversation.id, handle: handle)
    }

    /// Mark all visible messages as read by current user
    /// [Source: Story 3.6 - Group Read Receipts]
    private func markVisibleMessagesAsRead() async {
        await MessageService.shared.markMessagesAsRead(
            messages: messages,
            conversationID: conversation.id,
            modelContext: modelContext
        )
    }
}
