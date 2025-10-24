/// ConversationListView.swift
///
/// Main view showing list of conversations
/// Features real-time updates, search, swipe actions, pull-to-refresh, network status
///
/// Created: 2025-10-21
/// [Source: Story 2.2 - Display Conversation List]

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase

/// Main view displaying all conversations with real-time updates
struct ConversationListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext

    // Query non-archived conversations sorted by last message timestamp
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            conversation.isArchived == false
        },
        sort: [SortDescriptor(\ConversationEntity.updatedAt, order: .reverse)]
    ) private var conversations: [ConversationEntity]

    @State private var viewModel: ConversationViewModel?
    @State private var showRecipientPicker = false
    @State private var showGroupCreation = false
    @State private var showProfile = false
    @State private var searchText = ""
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Computed Properties

    var filteredConversations: [ConversationEntity] {
        if searchText.isEmpty {
            return Array(conversations)
        }
        return conversations.filter { conversation in
            // Search by last message content
            if let lastMessage = conversation.lastMessageText,
               lastMessage.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // TODO: Search by recipient name when recipient loading is implemented
            return false
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Network status banner
                if !networkMonitor.isConnected {
                    NetworkStatusBanner()
                }

                // Story 5.4: Message Andrew button for fans
                if authViewModel.currentUser?.isFan == true {
                    messageAndrewButton
                }

                // Conversations or empty state
                if filteredConversations.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else if filteredConversations.isEmpty {
                    emptySearchView
                } else {
                    conversationsList
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    profileButton
                }

                ToolbarItem(placement: .topBarLeading) {
                    newGroupButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    newMessageButton
                }
            }
            .refreshable {
                await viewModel?.syncConversations()
            }
            .task {
                setupViewModel()
                await viewModel?.startRealtimeListener()

                // 🆕 Analyze conversations when creator opens inbox (Story 6.11)
                if authViewModel.currentUser?.isCreator == true {
                    await analyzeConversationsIfNeeded()
                }
            }
            .onDisappear {
                viewModel?.stopRealtimeListener()
                viewModel = nil  // Explicitly release ViewModel
            }
            .sheet(isPresented: $showRecipientPicker) {
                RecipientPickerView(onSelect: { userID in
                    Task {
                        await createConversation(withUserID: userID)
                    }
                }, currentUser: authViewModel.currentUser)
            }
            .sheet(isPresented: $showGroupCreation) {
                GroupCreationView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
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
    }

    // MARK: - Subviews

    /// Story 5.4: Message Andrew button for fans
    private var messageAndrewButton: some View {
        Button {
            Task {
                await createDMWithCreator()
            }
        } label: {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Message Andrew")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .accessibilityLabel("Message Andrew")
        .accessibilityHint("Start a direct message conversation with Andrew")
    }

    private var profileButton: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("Profile")
        .accessibilityHint("View and edit your profile")
    }

    private var newGroupButton: some View {
        Button {
            showGroupCreation = true
        } label: {
            Image(systemName: "person.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("New Channel")
        .accessibilityHint("Create a channel conversation with multiple participants")
    }

    private var newMessageButton: some View {
        Button {
            showRecipientPicker = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("New Message")
        .accessibilityHint("Start a new conversation")
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Conversations",
            systemImage: "message",
            description: Text("Tap + to start messaging")
        )
        .listRowSeparator(.hidden)
    }

    private var emptySearchView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "magnifyingglass",
            description: Text("No conversations match '\(searchText)'")
        )
        .listRowSeparator(.hidden)
    }

    private var conversationsList: some View {
        ForEach(filteredConversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRowView(conversation: conversation)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    archiveConversation(conversation)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
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

                Button(role: .destructive) {
                    deleteConversation(conversation)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationDestination(for: ConversationEntity.self) { conversation in
            MessageThreadView(conversation: conversation)
        }
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConversationViewModel(modelContext: modelContext)
        }
    }

    private func createConversation(withUserID userID: String) async {
        guard let viewModel = viewModel else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let _ = try await viewModel.createConversation(
                withUserID: userID,
                currentUserID: currentUserID
            )
        } catch {
            // Error is already set in viewModel.error and will be displayed in UI
        }
    }

    /// Story 5.4: Create DM with creator (Andrew)
    private func createDMWithCreator() async {
        guard let viewModel = viewModel else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        do {
            let _ = try await viewModel.createDMWithCreator(currentUserID: currentUserID)
        } catch {
            // Error is already set in viewModel.error and will be displayed in UI
        }
    }

    /// 🆕 Story 6.11: Analyze conversations when creator opens inbox
    /// Only analyzes conversations with new messages since last analysis
    private func analyzeConversationsIfNeeded() async {
        print("\n🔵 [ANALYSIS] Starting analysis check...")
        print("🔵 [ANALYSIS] Current user isCreator: \(authViewModel.currentUser?.isCreator == true)")
        print("🔵 [ANALYSIS] Total conversations: \(conversations.count)")

        // Get conversations with new messages
        let conversationsToAnalyze = conversations.filter {
            $0.messageCountSinceAnalysis > 0
        }

        print("🔵 [ANALYSIS] Conversations needing analysis: \(conversationsToAnalyze.count)")

        // Log each conversation's state
        for conv in conversations.prefix(5) {  // Limit to first 5 to avoid spam
            print("🔵 [ANALYSIS] Conv \(conv.id.prefix(8)): messageCount=\(conv.messageCountSinceAnalysis), category=\(conv.aiCategory ?? "nil"), sentiment=\(conv.aiSentiment ?? "nil"), score=\(conv.aiBusinessScore?.description ?? "nil")")
        }

        guard !conversationsToAnalyze.isEmpty else {
            print("🔴 [ANALYSIS] No conversations need analysis - SKIPPING\n")
            return
        }

        print("✅ [ANALYSIS] Analyzing \(conversationsToAnalyze.count) conversations...")

        await ConversationAnalysisService.shared.analyzeAllConversations(conversationsToAnalyze)

        print("✅ [ANALYSIS] Analysis complete\n")
    }

    private func archiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = true
        try? modelContext.save()

        // Sync to RTDB
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

    private func deleteConversation(_ conversation: ConversationEntity) {
        modelContext.delete(conversation)
        try? modelContext.save()

        // Delete from RTDB
        Task {
            let conversationRef = Database.database().reference().child("conversations/\(conversation.id)")
            try? await conversationRef.removeValue()
        }

    }
}

// MARK: - Preview

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationEntity.self, MessageEntity.self, UserEntity.self])
        .environmentObject(NetworkMonitor.shared)
}
