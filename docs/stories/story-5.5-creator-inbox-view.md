# Story 5.5: Creator Inbox View

## Status
Draft

## Story
**As** Andrew (the creator),
**I want** to see all my fan DMs in one dedicated inbox,
**so that** I can efficiently manage fan communication (and later use AI features).

## Acceptance Criteria

1. Creator sees "Inbox" tab with all fan DM conversations
2. Inbox shows only DM conversations (no group chats/channels)
3. Conversations are sorted by most recent message first
4. Unread badge count displays on Inbox tab
5. Each conversation row shows fan name, last message preview, timestamp
6. Tapping conversation opens message thread
7. Fans see "DMs" tab showing their conversation with Andrew only
8. Fan DM tab shows single conversation (or empty state if no DM yet)
9. Inbox view is only visible to creator (not fans)
10. Real-time updates when new fan messages arrive

## Tasks / Subtasks

- [ ] Create InboxView for creator (AC: 1, 2, 3, 9)
  - [ ] Create new InboxView.swift file
  - [ ] Filter conversations to show only DMs (isGroup = false)
  - [ ] Sort conversations by lastMessageAt descending
  - [ ] Use @Query to fetch DM conversations
  - [ ] Reuse ConversationRowView for list items
  - [ ] Add pull-to-refresh functionality

- [ ] Implement unread badge counting (AC: 4)
  - [ ] Create computed property for total unread DMs
  - [ ] Sum unreadCount across all DM conversations
  - [ ] Display badge on Inbox tab with count
  - [ ] Update badge in real-time as messages arrive
  - [ ] Clear badge when user opens conversations

- [ ] Style conversation rows for inbox (AC: 5)
  - [ ] Show fan profile photo
  - [ ] Display fan display name
  - [ ] Show last message preview (truncated)
  - [ ] Display relative timestamp ("2m ago", "1h ago")
  - [ ] Highlight unread conversations (bold text or indicator)
  - [ ] Add swipe actions (mark as read, archive - future)

- [ ] Add navigation to message thread (AC: 6)
  - [ ] Tap conversation row → navigate to MessageThreadView
  - [ ] Pass conversation entity to thread view
  - [ ] Reuse existing MessageThreadView (no changes needed)
  - [ ] Navigation stack handles back button

- [ ] Create simplified DM view for fans (AC: 7, 8)
  - [ ] Create FanDMView showing single Andrew conversation
  - [ ] If no DM exists, show empty state with "Message Andrew" button
  - [ ] If DM exists, show single conversation row or direct thread
  - [ ] Remove conversation list if only one exists

- [ ] Add conditional tab visibility (AC: 9)
  - [ ] Show "Inbox" tab only if user.isCreator
  - [ ] Show "DMs" tab only if user is fan
  - [ ] Hide inappropriate tabs based on userType
  - [ ] Ensure tab bar updates when user changes

- [ ] Implement real-time inbox updates (AC: 10)
  - [ ] Listen to SwiftData changes via @Query
  - [ ] Inbox automatically refreshes when new messages arrive
  - [ ] Conversation order updates when new message received
  - [ ] Unread count updates in real-time
  - [ ] No manual refresh needed

- [ ] Add empty state for inbox (AC: 1)
  - [ ] Show empty state if no fan DMs exist
  - [ ] Display helpful message: "No fan messages yet"
  - [ ] Add illustration or icon
  - [ ] Explain that fans can message Andrew

## Dev Notes

### Architecture Context

**Inbox View Structure:**
```swift
struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ConversationEntity> { conversation in
            !conversation.isGroup
        },
        sort: \ConversationEntity.lastMessageAt,
        order: .reverse
    ) private var dmConversations: [ConversationEntity]

    var totalUnread: Int {
        dmConversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        List(dmConversations) { conversation in
            ConversationRowView(conversation: conversation)
                .onTapGesture {
                    // Navigate to MessageThreadView
                }
        }
        .navigationTitle("Inbox")
        .badge(totalUnread)
    }
}
```

**Fan DM View:**
```swift
struct FanDMView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [ConversationEntity]

    var andrewConversation: ConversationEntity? {
        conversations.first { conversation in
            !conversation.isGroup &&
            conversation.participantIDs.contains(AppConstants.CREATOR_ID)
        }
    }

    var body: some View {
        if let conversation = andrewConversation {
            // Show conversation with Andrew
            NavigationLink(value: conversation) {
                ConversationRowView(conversation: conversation)
            }
        } else {
            // Empty state with "Message Andrew" button
            EmptyDMView()
        }
    }
}
```

**Tab Bar Conditional Display:**
```swift
TabView {
    ChannelsView()
        .tabItem { Label("Channels", systemImage: "bubble.left.and.bubble.right") }

    if currentUser.isCreator {
        InboxView()
            .tabItem { Label("Inbox", systemImage: "tray") }
            .badge(inboxUnreadCount)
    } else {
        FanDMView()
            .tabItem { Label("DMs", systemImage: "message") }
    }

    ProfileView()
        .tabItem { Label("Profile", systemImage: "person.circle") }
}
```

### Source Tree
```
Core/
├── Views/
│   ├── Inbox/
│   │   ├── InboxView.swift (NEW - Creator inbox)
│   │   ├── FanDMView.swift (NEW - Fan DM view)
│   │   └── EmptyDMView.swift (NEW - Empty state)
│   ├── Conversations/
│   │   └── ConversationRowView.swift (Reuse existing)
│   └── Main/
│       └── MainTabView.swift (Update with conditional tabs)
└── ViewModels/
    └── InboxViewModel.swift (Optional - for complex logic)
```

### Inbox Features
- **Sorting:** Most recent message first (real-time)
- **Filtering:** DMs only (isGroup = false)
- **Unread Count:** Sum of all DM unread counts
- **Real-time:** Auto-updates via @Query SwiftData
- **Navigation:** Tap → MessageThreadView (existing)

### UI Components to Reuse
- ✅ ConversationRowView (from Epic 2)
- ✅ MessageThreadView (from Epic 2)
- ✅ Message bubbles and composer (from Epic 2)
- ✅ TabView structure (existing)

### Future AI Integration (Epic 6)
This inbox view is designed to support AI features:
- Auto-categorization of DMs
- Smart reply suggestions
- Sentiment analysis
- Priority sorting
- Business opportunity detection

### Dependencies
- **Depends on:** Epic 2 (One-on-One Chat) - DM infrastructure
- **Depends on:** Story 5.2 (User Type) - Creator identification
- **Depends on:** Story 5.4 (DM Restrictions) - Ensures only valid DMs
- **Enables:** Epic 6 (AI Features) - Inbox is foundation for AI

## Testing

### Testing Standards
- Manual testing with creator and fan accounts
- Test on simulator for quick iteration
- Test real-time updates across devices
- Verify unread counting logic

### Test Cases

1. **Creator Inbox - Basic Display:**
   - Login as Andrew (creator)
   - Navigate to Inbox tab
   - Verify tab shows "Inbox" label
   - See list of fan DM conversations
   - Each row shows fan name, preview, timestamp

2. **Creator Inbox - No DMs:**
   - Login as Andrew with no fan DMs
   - Navigate to Inbox
   - See empty state message
   - Verify helpful empty state UI

3. **Creator Inbox - Sorting:**
   - Have multiple fan DMs with different timestamps
   - Verify conversations sorted by most recent first
   - Send new message in older conversation
   - Verify conversation moves to top

4. **Creator Inbox - Unread Badge:**
   - Have unread messages from fans
   - Check Inbox tab badge shows correct count
   - Open conversation and read messages
   - Verify badge count decreases
   - Check badge disappears when all read

5. **Fan DM View - Has Conversation:**
   - Login as fan who has DM with Andrew
   - Navigate to DMs tab
   - See single Andrew conversation
   - Tap conversation → opens message thread

6. **Fan DM View - No Conversation:**
   - Login as fan with no DM to Andrew
   - Navigate to DMs tab
   - See empty state
   - See "Message Andrew" button
   - Tap button → creates DM

7. **Tab Visibility:**
   - Login as creator → see "Inbox" tab
   - Login as fan → see "DMs" tab (not "Inbox")
   - Verify correct tab selected on launch
   - Check tab icons and labels

8. **Real-Time Updates:**
   - Login as creator on one device
   - Send message from fan on another device
   - Verify inbox updates immediately
   - Check conversation moves to top
   - Verify unread badge increments

9. **Navigation:**
   - Tap conversation in inbox
   - Opens MessageThreadView
   - Send message
   - Navigate back to inbox
   - Verify conversation updated with new message

10. **Offline Support:**
    - Disconnect internet
    - Open inbox
    - Verify conversations load from SwiftData cache
    - View message history
    - Reconnect → verify sync

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2025-10-22 | 1.0 | Initial story creation from Epic 5 | Sarah (PO) |

## Dev Agent Record

### Agent Model Used
_To be filled by dev agent_

### Debug Log References
_To be filled by dev agent_

### Completion Notes List
_To be filled by dev agent_

### File List
_To be filled by dev agent_

## QA Results
_To be filled by QA agent_
