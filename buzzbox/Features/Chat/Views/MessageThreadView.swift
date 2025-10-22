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

    // Presence status state
    @State private var presenceStatus: PresenceStatus?
    @State private var presenceHandle: DatabaseHandle?

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
                                onRetry: { failedMessage in
                                    Task {
                                        await viewModel.retryFailedMessage(failedMessage)
                                    }
                                }
                            )
                            .id(message.id)
                        }

                        // Typing indicator at bottom
                        if !typingUserIDs.isEmpty {
                            HStack {
                                TypingIndicatorView()
                                Spacer()
                            }
                            .padding(.horizontal)
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

            // Message input composer
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
        }
        .navigationTitle(recipientDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(recipientDisplayName)
                        .font(.headline)

                    // ✅ Presence status subtitle
                    // [Source: Story 2.8 - User Presence & Online Status]
                    if let status = presenceStatus, !conversation.isGroup {
                        Text(status.displayText)
                            .font(.caption)
                            .foregroundStyle(status.isOnline ? .green : .secondary)
                    }
                }
            }
        }
        .task {
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

            await loadRecipientName()
            await viewModel.startRealtimeListener()
            await viewModel.markAsRead()
        }
        .onDisappear {
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

            viewModel.stopRealtimeListener()
        }
    }

    // MARK: - Private Methods

    private func sendMessage() async {
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
}
