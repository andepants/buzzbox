/// InboxView.swift
///
/// Creator's inbox view showing all fan DM conversations
/// Filters to show only one-on-one conversations (isGroup = false)
/// Sorted by most recent message first with real-time updates
///
/// Created: 2025-10-22
/// [Source: Story 5.5 - Creator Inbox View]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

/// Creator's inbox view for managing fan DMs
/// Only visible to users with userType = .creator
struct InboxView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor

    // Query DM conversations only (isGroup = false), sorted by most recent
    // Note: Cannot sort by isPinned (Bool) in @Query for SwiftData models
    // Sorting by pinned status is handled in filteredConversations computed property
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            !conversation.isGroup && !conversation.isArchived
        },
        sort: [
            SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)
        ]
    ) private var dmConversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var searchText = ""

    // MARK: - Message Listener Properties

    /// Active message listeners for all DM conversations (conversationID -> DatabaseHandle)
    @State private var messageListeners: [String: DatabaseHandle] = [:]

    /// Listener start time for historical message filtering
    @State private var listenerStartTime: Date?

    // MARK: - Initialization

    /// Initializer for InboxView
    /// Note: @Query properties don't need to be passed as parameters
    init() {
        // SwiftData @Query is automatically initialized by the system
    }

    // MARK: - Computed Properties

    /// Total unread count across all DM conversations
    var totalUnread: Int {
        dmConversations.reduce(0) { $0 + $1.unreadCount }
    }

    /// Filtered conversations based on search text, sorted by pinned status
    var filteredConversations: [ConversationEntity] {
        let filtered: [ConversationEntity]
        if searchText.isEmpty {
            filtered = Array(dmConversations)
        } else {
            filtered = dmConversations.filter { conversation in
                if let lastMessage = conversation.lastMessageText,
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

                    // Conversations or empty state
                    if filteredConversations.isEmpty && searchText.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else if filteredConversations.isEmpty {
                        emptySearchView
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        conversationsList
                    }
                }
                .padding(.top, 8)
            }
        }
        .searchable(text: $searchText, prompt: "Search fan messages")
        .navigationDestination(for: ConversationEntity.self) { conversation in
            MessageThreadView(conversation: conversation)
        }
        .refreshable {
            await viewModel?.syncConversations()
        }
        .task {
            setupViewModel()
            await viewModel?.startRealtimeListener()
            await startMessageListeners()

            // 🆕 Analyze conversations when creator opens inbox (Story 6.11)
            if authViewModel.currentUser?.isCreator == true {
                await analyzeConversationsIfNeeded()
            }
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
            "No Fan Messages Yet",
            systemImage: "tray",
            description: Text("Fan DM conversations will appear here.\nFans can message you from the app.")
        )
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No conversations match '\(searchText)'")
        )
    }

    private var conversationsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredConversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRowView(conversation: conversation)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                    }
                )
                .contextMenu {
                    Button {
                        togglePin(conversation)
                    } label: {
                        Label(
                            conversation.isPinned ? "Unpin" : "Pin",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        toggleUnread(conversation)
                    } label: {
                        Label(
                            conversation.unreadCount > 0 ? "Mark as Read" : "Mark as Unread",
                            systemImage: "envelope.badge"
                        )
                    }

                    Button {
                        archiveConversation(conversation)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
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

    /// 🆕 Story 6.11: Analyze conversations when creator opens inbox
    /// Only analyzes conversations with new messages since last analysis
    private func analyzeConversationsIfNeeded() async {
        print("\n🔵 [INBOX-ANALYSIS] Starting analysis check...")
        print("🔵 [INBOX-ANALYSIS] Current user isCreator: \(authViewModel.currentUser?.isCreator == true)")
        print("🔵 [INBOX-ANALYSIS] Total DM conversations: \(dmConversations.count)")

        // Get conversations that need analysis:
        // 1. Has new messages since last analysis (messageCountSinceAnalysis > 0), OR
        // 2. Has never been analyzed before (aiAnalyzedAt == nil)
        let conversationsToAnalyze = dmConversations.filter {
            $0.messageCountSinceAnalysis > 0 || $0.aiAnalyzedAt == nil
        }

        print("🔵 [INBOX-ANALYSIS] Conversations needing analysis: \(conversationsToAnalyze.count)")

        // Log each conversation's state (limit to first 5 to avoid spam)
        for conv in dmConversations.prefix(5) {
            print("🔵 [INBOX-ANALYSIS] Conv \(conv.id.prefix(8)): messageCount=\(conv.messageCountSinceAnalysis), category=\(conv.aiCategory ?? "nil"), sentiment=\(conv.aiSentiment ?? "nil"), score=\(conv.aiBusinessScore?.description ?? "nil")")
        }

        guard !conversationsToAnalyze.isEmpty else {
            print("🔴 [INBOX-ANALYSIS] No conversations need analysis - SKIPPING\n")
            return
        }

        print("✅ [INBOX-ANALYSIS] Analyzing \(conversationsToAnalyze.count) conversations...")

        await ConversationAnalysisService.shared.analyzeAllConversations(conversationsToAnalyze)

        // Save context after analysis updates
        try? modelContext.save()

        print("✅ [INBOX-ANALYSIS] Analysis complete\n")
    }

    private func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        try? modelContext.save()

        // Sync to Firebase
        Task {
            try? await ConversationService.shared.syncConversation(conversation)
        }

    }

    private func togglePin(_ conversation: ConversationEntity) {
        conversation.isPinned.toggle()
        try? modelContext.save()

        // Haptic feedback
        #if os(iOS)
        HapticFeedback.impact(.light)
        #endif

    }

    private func toggleUnread(_ conversation: ConversationEntity) {
        conversation.unreadCount = conversation.unreadCount > 0 ? 0 : 1
        try? modelContext.save()

    }

    // MARK: - Message Listener Methods

    /// Starts listening to messages for all DM conversations
    private func startMessageListeners() async {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("⚠️ [INBOX] Cannot start message listeners: No authenticated user")
            return
        }

        listenerStartTime = Date()
        print("🔔 [INBOX] Starting message listeners for \(dmConversations.count) DM conversations")
        print("    └─ ListenerStartTime: \(ISO8601DateFormatter().string(from: listenerStartTime!))")

        // Set up listeners for each DM conversation
        for conversation in dmConversations {
            setupMessageListener(conversationID: conversation.id, currentUserID: currentUserID)
        }

        print("✅ [INBOX] All \(dmConversations.count) message listeners active")
    }

    /// Stops all active message listeners
    private func stopMessageListeners() {
        guard !messageListeners.isEmpty else {
            return
        }

        print("🔔 [INBOX] Stopping message listeners")
        print("    └─ Active listeners: \(messageListeners.count)")

        let database = Database.database().reference()

        for (conversationID, handle) in messageListeners {
            database.child("messages/\(conversationID)").removeObserver(withHandle: handle)
            print("    └─ Stopped listener for: \(conversationID)")
        }

        messageListeners.removeAll()
        listenerStartTime = nil

        print("✅ [INBOX] All message listeners stopped")
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
            print("❌ [INBOX] Listener error for \(conversationID): \(error.localizedDescription)")
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
        print("📥 [INBOX] Message detected in DM conversation")
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

        print("🔔 [INBOX] Triggering notifications")
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

        print("✅ [INBOX] Notifications triggered successfully")
    }

    /// Fetches sender display name from Firestore
    private func fetchSenderName(senderID: String) async -> String {
        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("users").document(senderID).getDocument()
            return doc.data()?["displayName"] as? String ?? "Unknown User"
        } catch {
            print("⚠️ [INBOX] Failed to fetch sender name: \(error.localizedDescription)")
            return "Unknown User"
        }
    }
}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self], inMemory: true)
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(AuthViewModel())
}
