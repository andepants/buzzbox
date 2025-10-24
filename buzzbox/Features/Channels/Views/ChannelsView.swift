/// ChannelsView.swift
///
/// Main view showing list of channels (group conversations)
/// Features real-time updates, search, swipe actions, pull-to-refresh
/// No "New Group" button - channels are pre-seeded by admin
///
/// Created: 2025-10-22
/// [Source: Story 5.6 - Simplified Navigation]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

/// Main view displaying all channels (groups) with real-time updates
struct ChannelsView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext

    // Query group conversations only (isGroup = true), sorted by last message
    // Note: Cannot sort by isPinned (Bool) in @Query for SwiftData models
    // Sorting by pinned status is handled in filteredChannels computed property
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isGroup && conversation.isArchived == false
        },
        sort: [
            SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)
        ]
    ) private var channels: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var searchText = ""
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Message Listener Properties

    /// Active message listeners for all channel conversations (conversationID -> DatabaseHandle)
    @State private var messageListeners: [String: DatabaseHandle] = [:]

    /// Listener start time for historical message filtering
    @State private var listenerStartTime: Date?

    // MARK: - Initialization

    /// Initializer for ChannelsView
    /// Note: @Query properties don't need to be passed as parameters
    init() {
        // SwiftData @Query is automatically initialized by the system
    }

    // MARK: - Computed Properties

    var filteredChannels: [ConversationEntity] {
        let filtered: [ConversationEntity]
        if searchText.isEmpty {
            filtered = Array(channels)
        } else {
            filtered = channels.filter { channel in
                // Search by channel name
                if let displayName = channel.displayName,
                   displayName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                // Search by last message content
                if let lastMessage = channel.lastMessageText,
                   lastMessage.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }

        // Sort by pinned status first, then by updatedAt
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned // Pinned items first
            }
            return lhs.updatedAt > rhs.updatedAt // Then by most recent
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.03),
                    Color.blue.opacity(0.08),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Network status banner
                    if !networkMonitor.isConnected {
                        NetworkStatusBanner()
                    }

                    // Channels or empty state
                    if filteredChannels.isEmpty && searchText.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else if filteredChannels.isEmpty {
                        emptySearchView
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        channelsList
                    }
                }
                .padding(.top, 8)
            }
        }
        .searchable(text: $searchText, prompt: "Search channels")
        .navigationDestination(for: ConversationEntity.self) { channel in
            MessageThreadView(conversation: channel)
        }
        .refreshable {
            await viewModel?.syncConversations()
        }
        .task {
            setupViewModel()
            await viewModel?.startRealtimeListener()
            await startMessageListeners()
        }
        .onDisappear {
            viewModel?.stopRealtimeListener()
            viewModel = nil  // Explicitly release ViewModel
            stopMessageListeners()
        }
        .alert("Error", isPresented: .constant(viewModel?.error != nil)) {
            Button("OK") {
                viewModel?.error = nil
            }
        } message: {
            if let error = viewModel?.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Channels",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Channels will appear here when created by admins")
        )
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No channels match '\(searchText)'")
        )
    }

    private var channelsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredChannels) { channel in
                NavigationLink(value: channel) {
                    ChannelCardView(channel: channel)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                    }
                )
                .contextMenu {
                    Button {
                        togglePin(channel)
                    } label: {
                        Label(
                            channel.isPinned ? "Unpin" : "Pin",
                            systemImage: channel.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        toggleMute(channel)
                    } label: {
                        Label(
                            channel.isMuted ? "Unmute" : "Mute",
                            systemImage: channel.isMuted ? "bell" : "bell.slash"
                        )
                    }

                    Button {
                        toggleUnread(channel)
                    } label: {
                        Label(
                            channel.unreadCount > 0 ? "Mark as Read" : "Mark as Unread",
                            systemImage: "envelope.badge"
                        )
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    private func togglePin(_ channel: ConversationEntity) {
        channel.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        HapticFeedback.impact(.light)
        #endif

    }

    private func toggleMute(_ channel: ConversationEntity) {
        channel.isMuted.toggle()
        try? modelContext.save()

    }

    private func toggleUnread(_ channel: ConversationEntity) {
        channel.unreadCount = channel.unreadCount > 0 ? 0 : 1
        try? modelContext.save()

    }

    // MARK: - Message Listener Methods

    /// Starts listening to messages for all channel conversations
    private func startMessageListeners() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("⚠️ [CHANNELS] Cannot start message listeners: No authenticated user")
            return
        }

        listenerStartTime = Date()
        print("🔔 [CHANNELS] Starting message listeners for \(channels.count) channel conversations")
        print("    └─ ListenerStartTime: \(ISO8601DateFormatter().string(from: listenerStartTime!))")

        // Set up listeners for each channel conversation
        for channel in channels {
            setupMessageListener(conversationID: channel.id, currentUserID: currentUserID)
        }

        print("✅ [CHANNELS] All \(channels.count) message listeners active")
    }

    /// Stops all active message listeners
    private func stopMessageListeners() {
        guard !messageListeners.isEmpty else {
            return
        }

        print("🔔 [CHANNELS] Stopping message listeners")
        print("    └─ Active listeners: \(messageListeners.count)")

        let database = Database.database().reference()

        for (conversationID, handle) in messageListeners {
            database.child("messages/\(conversationID)").removeObserver(withHandle: handle)
            print("    └─ Stopped listener for: \(conversationID)")
        }

        messageListeners.removeAll()
        listenerStartTime = nil

        print("✅ [CHANNELS] All message listeners stopped")
    }

    /// Sets up a message listener for a specific conversation
    private func setupMessageListener(conversationID: String, currentUserID: String) {
        // Skip if already listening
        if messageListeners[conversationID] != nil {
            return
        }

        let database = Database.database().reference()
        let messagesRef = database.child("messages/\(conversationID)")

        // Listen to the LAST message only (most efficient)
        let query = messagesRef.queryLimited(toLast: 1)

        let handle = query.observe(.childAdded, with: { snapshot in
            Task { @MainActor in
                await self.handleIncomingMessage(
                    snapshot: snapshot,
                    conversationID: conversationID,
                    currentUserID: currentUserID
                )
            }
        }, withCancel: { error in
            print("❌ [CHANNELS] Listener error for \(conversationID): \(error.localizedDescription)")
        })

        messageListeners[conversationID] = handle
    }

    /// Handles an incoming message from RTDB
    private func handleIncomingMessage(
        snapshot: DataSnapshot,
        conversationID: String,
        currentUserID: String
    ) async {
        guard let messageData = snapshot.value as? [String: Any] else {
            return
        }

        let messageID = snapshot.key
        let senderID = messageData["senderID"] as? String ?? ""
        let messageText = messageData["text"] as? String ?? ""

        // Get message timestamp
        let serverTimestampMs = messageData["serverTimestamp"] as? Double ?? 0
        let messageTimestamp = serverTimestampMs > 0 ? Date(timeIntervalSince1970: serverTimestampMs / 1000.0) : nil

        // Determine if message is historical
        let isHistoricalMessage: Bool
        if let messageTimestamp = messageTimestamp, let listenerStartTime = listenerStartTime {
            isHistoricalMessage = messageTimestamp <= listenerStartTime
        } else {
            isHistoricalMessage = true
        }

        // Check if message is from current user
        let isFromCurrentUser = senderID == currentUserID

        // Check if user is viewing this conversation
        let currentScreen = UserPresenceService.shared.getCurrentConversationID()
        let isViewingConversation = currentScreen == conversationID

        // Determine if we should trigger notification
        let shouldTriggerNotification = !isFromCurrentUser && !isHistoricalMessage && !isViewingConversation

        // Log notification decision
        print("📥 [CHANNELS] Message detected in channel conversation")
        print("    └─ ConversationID: \(conversationID)")
        print("    └─ MessageID: \(messageID)")
        print("    └─ SenderID: \(senderID)")
        print("    └─ IsHistorical: \(isHistoricalMessage)")
        print("    └─ IsFromCurrentUser: \(isFromCurrentUser)")
        print("    └─ IsViewingConversation: \(isViewingConversation)")
        print("    └─ WillTriggerNotification: \(shouldTriggerNotification)")

        // Skip notification if conditions not met
        guard shouldTriggerNotification else {
            if isFromCurrentUser {
                print("    └─ ⏭️  Skipped: Message from current user")
            } else if isHistoricalMessage {
                print("    └─ ⏭️  Skipped: Historical message")
            } else if isViewingConversation {
                print("    └─ ⏭️  Skipped: User viewing this conversation")
            }
            return
        }

        // Trigger notification
        print("    └─ 🔔 Triggering notification...")
        await triggerNotificationForMessage(
            messageID: messageID,
            senderID: senderID,
            text: messageText,
            conversationID: conversationID
        )
    }

    /// Triggers notification for a new message
    private func triggerNotificationForMessage(
        messageID: String,
        senderID: String,
        text: String,
        conversationID: String
    ) async {
        // Fetch sender's name
        let senderName = await fetchSenderName(senderID: senderID)

        print("🔔 [CHANNELS] Triggering notifications")
        print("    └─ Sender: \(senderName)")
        print("    └─ MessageID: \(messageID)")
        print("    └─ ConversationID: \(conversationID)")

        // Trigger in-app notification
        await NotificationService.shared.showInAppNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )

        // Trigger local notification
        await NotificationService.shared.scheduleLocalNotification(
            title: senderName,
            body: text,
            conversationID: conversationID
        )

        print("✅ [CHANNELS] Notifications triggered successfully")
    }

    /// Fetches sender display name from Firestore
    private func fetchSenderName(senderID: String) async -> String {
        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("users").document(senderID).getDocument()
            return doc.data()?["displayName"] as? String ?? "Unknown User"
        } catch {
            print("⚠️ [CHANNELS] Failed to fetch sender name: \(error.localizedDescription)")
            return "Unknown User"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChannelsView()
    }
    .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
    .environmentObject(NetworkMonitor.shared)
    .environmentObject(AuthViewModel())
}
