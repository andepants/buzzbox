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
                            MessageBubbleView(message: message)
                                .id(message.id)
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
        }
        .navigationTitle(recipientDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRecipientName()
            await viewModel.startRealtimeListener()
            await viewModel.markAsRead()
        }
        .onDisappear {
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
}
