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
    @Environment(\.scenePhase) private var scenePhase

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var recipientDisplayName: String

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

    // Smart reply state (Story 6.10 - updated for FAB)
    @State private var isLoadingDrafts = false
    @State private var errorMessage = ""
    @State private var showError = false

    // AI Service for smart replies (Story 6.10)
    private let aiService = AIService()

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

        // ⚡️ OPTIMIZED: Set display name immediately for channels (no async load needed)
        // For DMs, loadRecipientName() will update this asynchronously
        _recipientDisplayName = State(initialValue: conversation.isGroup
            ? (conversation.displayName ?? "Group Chat")
            : "Loading...")
    }

    // MARK: - Computed Properties

    /// Check if current user is the creator (Story 6.7)
    private var isCreator: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return false
        }
        return currentUserID == Constants.CREATOR_UID
    }

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
                    .padding(.bottom, 70)
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

                    // Auto-mark new messages as read when chat is open
                    if newCount > oldCount {
                        Task {
                            await markVisibleMessagesAsRead()
                        }
                    }
                }
            }

            // Message input composer or read-only banner
            if canPost {
                VStack(spacing: 0) {
                    // AI Bar with full-width blur background (Story 6.10)
                    if isCreator && !messages.isEmpty {
                        ZStack {
                            // Full-width white background
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 56)

                            // FAB buttons centered
                            FloatingFABView(
                                onReplyGenerated: { draft in
                                    messageText = draft
                                    isInputFocused = true
                                },
                                generateReply: { type in
                                    // Check cache first (Story 6.10: Smart Replies Caching)
                                    if let lastMessage = messages.last,
                                       lastMessage.hasValidSmartRepliesCache {
                                        // Return cached reply based on type
                                        switch type {
                                        case .short:
                                            if let cached = lastMessage.smartReplyShort {
                                                return cached
                                            }
                                        case .funny:
                                            if let cached = lastMessage.smartReplyMedium {
                                                return cached
                                            }
                                        case .professional:
                                            if let cached = lastMessage.smartReplyDetailed {
                                                return cached
                                            }
                                        }
                                    }

                                    // Cache miss - generate new reply
                                    return try await aiService.generateSingleSmartReply(
                                        conversationId: conversation.id,
                                        messageText: messages.last?.text ?? "",
                                        replyType: type.rawValue
                                    )
                                }
                            )
                            .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Message input composer
                    MessageComposerView(
                        text: $messageText,
                        characterLimit: 10_000,
                        onSend: {
                            await sendMessage()
                        }
                    )
                    .focused($isInputFocused)
                    .disabled(isLoadingDrafts) // Disable during generation
                    .onChange(of: messageText) { oldValue, newValue in
                        handleTypingChange(newValue)
                    }
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {

            // Notify NotificationService that user is viewing this conversation
            // (prevents duplicate in-app notifications for this conversation)
            NotificationService.shared.setCurrentConversation(conversation.id)

            // Update user presence in RTDB with current screen
            // (allows Cloud Functions to know user is actively viewing this conversation)
            await UserPresenceService.shared.updateCurrentScreen(conversationID: conversation.id)

            // ⚡️ OPTIMIZED: Run independent operations in parallel
            async let permissionCheck: Void = checkPostingPermission()
            async let participantsLoad: Void = loadParticipants()
            async let recipientNameLoad: Void = loadRecipientName()
            async let presenceStart: Void = startPresenceListener()
            async let realtimeStart: Void = viewModel.startRealtimeListener()

            // Start typing listener (synchronous, no await needed)
            typingListenerHandle = TypingIndicatorService.shared.listenToTypingIndicators(
                conversationID: conversation.id
            ) { userIDs in
                withAnimation {
                    typingUserIDs = userIDs.filter { $0 != Auth.auth().currentUser?.uid }
                }
            }

            // Start read receipt listener (synchronous)
            startReadReceiptListener()

            // Wait for all parallel operations to complete
            await (permissionCheck, participantsLoad, recipientNameLoad, presenceStart, realtimeStart)

            // Mark messages as read after everything is loaded
            await markVisibleMessagesAsRead()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Mark messages as read when app comes to foreground with chat open
            if newPhase == .active && oldPhase != .active {
                Task {
                    await markVisibleMessagesAsRead()
                }
            }
        }
        .onDisappear {

            // Clear current conversation tracking for notifications
            NotificationService.shared.setCurrentConversation(nil)

            // Clear user presence screen tracking in RTDB
            Task {
                await UserPresenceService.shared.updateCurrentScreen(conversationID: nil)
            }

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
            canPost = false
            return
        }


        // ✅ DMs: Always allow posting (both participants can message each other)
        if !conversation.isGroup {
            canPost = true
            return
        }

        // ✅ Channels: Check creator-only restrictions
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.id == currentUserID }
        )

        do {
            let users = try modelContext.fetch(descriptor)
            guard let currentUser = users.first else {
                canPost = false
                return
            }


            canPost = conversation.canUserPost(isCreator: currentUser.isCreator)


            if !canPost {
            }
        } catch {
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

            // Fetch missing users from cache/Firestore
            for userID in missingUserIDs {
                if let userData = try? await ConversationService.shared.getUser(userID: userID, modelContext: modelContext) {
                    participants.append(userData)
                }
            }
        } catch {
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
                    #if os(iOS)
                    HapticFeedback.notification(.error)
                    #endif
                    return
                }
            } catch {
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
            HapticFeedback.notification(.error)
            #endif
            return
        }

        let text = messageText
        messageText = "" // Clear input immediately (optimistic UI)

        // Send message
        await viewModel.sendMessage(text: text)

        // Haptic feedback
        #if os(iOS)
        HapticFeedback.impact(.light)
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
        // ⚡️ OPTIMIZED: Only DMs need async load (channels set name in init)
        guard !conversation.isGroup else { return }

        // For DMs, load the recipient's display name
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        guard let recipientID = conversation.getRecipientID(currentUserID: currentUserID) else {
            return
        }

        // Load recipient user from SwiftData cache
        if let recipientUser = try? await ConversationService.shared.getUser(userID: recipientID, modelContext: modelContext) {
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

                // Update message status to .read if any user has read it
                // (sender sees blue checkmarks when recipient has read)
                if !readByDates.isEmpty && message.status != .read {
                    message.status = .read
                }

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
