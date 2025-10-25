# Story 8.2: Archived Conversations View

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 1 - Foundation Polish
**Priority:** P0 (Critical for demo)
**Effort:** 2.5 hours
**Status:** Ready for Development

---

## Goal

Provide access to archived conversations via a toolbar button, allowing users to view, search, and unarchive conversations.

---

## User Story

**As** Andrew (The Creator),
**I want** to access my archived conversations,
**So that** I can review past conversations and unarchive them if needed.

---

## Dependencies

- ✅ Epic 5: Single-Creator Platform (provides inbox structure)
- ✅ Epic 6: AI Features (provides ConversationEntity with isArchived property)
- ⚠️ **Story 8.1:** Swipe-to-Archive (creates archived conversations)

---

## Implementation

### Toolbar Button

Add archive button to InboxView toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            showArchivedView = true
        } label: {
            Image(systemName: "archivebox")
        }
        .accessibilityLabel("View archived conversations")
        .badge(archivedCount > 0 ? archivedCount : nil)
    }
}
```

### ArchivedInboxView Component

Create new view `ArchivedInboxView.swift`:

```swift
struct ArchivedInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ConversationEntity> { $0.isArchived })
    private var archivedConversations: [ConversationEntity]

    @State private var searchText = ""

    var filteredConversations: [ConversationEntity] {
        if searchText.isEmpty {
            return archivedConversations
        }
        return archivedConversations.filter { conversation in
            // Search logic
        }
    }

    var body: some View {
        NavigationStack {
            if filteredConversations.isEmpty {
                emptyStateView
            } else {
                conversationList
            }
        }
        .searchable(text: $searchText, prompt: "Search archived")
    }

    private var conversationList: some View {
        List {
            ForEach(filteredConversations) { conversation in
                ConversationRowView(conversation: conversation)
                    .opacity(0.6) // Dimmed appearance
                    .swipeActions(edge: .trailing) {
                        Button {
                            unarchiveConversation(conversation)
                        } label: {
                            Label("Unarchive", systemImage: "tray.and.arrow.up")
                        }
                        .tint(.blue)
                    }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No archived conversations",
            systemImage: "archivebox",
            description: Text("Archived conversations will appear here")
        )
    }

    func unarchiveConversation(_ conversation: ConversationEntity) {
        conversation.isArchived = false
        HapticFeedback.impact(.medium)
    }
}
```

### Sheet Presentation

In InboxView, add sheet:

```swift
@State private var showArchivedView = false

.sheet(isPresented: $showArchivedView) {
    ArchivedInboxView()
}
```

### Count Badge

Calculate archived count:

```swift
@Query(filter: #Predicate<ConversationEntity> { $0.isArchived })
private var archivedConversations: [ConversationEntity]

var archivedCount: Int {
    archivedConversations.count
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Archive button appears in top right of InboxView toolbar
- ✅ Tapping archive button opens sheet with archived conversations
- ✅ Archived conversations shown dimmed (0.6 opacity)
- ✅ Right swipe unarchives conversation
- ✅ Empty state shows when no archived conversations
- ✅ Count badge shows archive count (if > 0)

### Visual Requirements
- ✅ Archived conversations have dimmed appearance
- ✅ Empty state uses ContentUnavailableView
- ✅ Sheet presents with proper navigation stack
- ✅ Badge appears only when count > 0

### Search Requirements
- ✅ Search bar appears at top of archived view
- ✅ Search filters by participant name or message content
- ✅ Empty search results show "No results" message

---

## Edge Cases & Error Handling

### Performance with Large Archives
- ✅ **Behavior:** Lazy loading for >100 archived conversations (pagination)
- ✅ **Implementation:** Use List with LazyVStack for efficient rendering

### Search Functionality
- ✅ **Behavior:** `.searchable()` modifier works within archived view
- ✅ **Implementation:** Filter archived conversations based on searchText

### Notification Muting
- ✅ **Behavior:** Archived conversations don't trigger push notifications
- ✅ **Implementation:** See Story 8.12 for NotificationService changes

### Navigation to Archived Thread
- ✅ **Behavior:** Tapping archived conversation opens thread with "Unarchive" button in toolbar
- ✅ **Implementation:** Add conditional toolbar button in MessageThreadView

### Read-Only Mode (Optional)
- ✅ **Behavior:** Optional - archive thread is read-only until unarchived
- ✅ **Implementation:** Add `isArchived` check to message input

### Empty Filter State
- ✅ **Behavior:** Shows helpful message when search returns no results
- ✅ **Implementation:** Conditional ContentUnavailableView for empty search

---

## Files to Create

### New View
- `buzzbox/Features/Inbox/Views/ArchivedInboxView.swift`
  - Main archived conversations view
  - Search functionality
  - Unarchive swipe action
  - Empty state handling

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add toolbar archive button
  - Add sheet presentation
  - Add archived count calculation

### Secondary Files
- `buzzbox/Core/Services/NotificationService.swift`
  - Check `isArchived` before notifying (Story 8.12)
  - Mute archived conversations

---

## Technical Notes

### SwiftData Query with Predicate

Use SwiftData's `@Query` macro with predicate filter:
```swift
@Query(filter: #Predicate<ConversationEntity> { $0.isArchived })
private var archivedConversations: [ConversationEntity]
```

### Dimmed Appearance

Apply opacity modifier to archived conversations:
```swift
.opacity(0.6) // Dimmed to indicate archived status
```

### Lazy Loading for Performance

For large archives, use lazy loading:
```swift
ScrollView {
    LazyVStack {
        ForEach(filteredConversations) { conversation in
            // Row view
        }
    }
}
```

### Search Implementation

Use SwiftUI's `.searchable()` modifier:
```swift
.searchable(text: $searchText, prompt: "Search archived")
```

---

## Testing Checklist

### Manual Testing
- [ ] Tap archive button → archived view opens
- [ ] View shows all archived conversations
- [ ] Archived conversations appear dimmed
- [ ] Right swipe unarchives conversation → moves back to inbox
- [ ] Search archived conversations → results filter correctly
- [ ] Archive 0 conversations → badge doesn't appear
- [ ] Archive 5 conversations → badge shows "5"

### Performance Testing
- [ ] Test with 100+ archived conversations → verify smooth scrolling
- [ ] Test search with large archive → verify responsive filtering
- [ ] Test unarchive with large archive → verify instant update

### Navigation Testing
- [ ] Tap archived conversation → thread opens
- [ ] Thread shows "Unarchive" button in toolbar
- [ ] Unarchive from thread → conversation moves to inbox
- [ ] Dismiss archived view → returns to inbox

### Edge Case Testing
- [ ] Search with no results → empty state shows
- [ ] Archive all conversations → inbox empty, archive full
- [ ] Unarchive all conversations → archive empty state shows

---

## Definition of Done

- ✅ Archive button appears in InboxView toolbar
- ✅ ArchivedInboxView created and functional
- ✅ Archived conversations display with dimmed appearance
- ✅ Right swipe unarchive works
- ✅ Search functionality implemented
- ✅ Empty states handled gracefully
- ✅ Count badge shows correct number
- ✅ Performance tested with large archives
- ✅ VoiceOver accessibility verified
- ✅ No regression in existing inbox functionality

---

## Related Stories

- **Story 8.1:** Swipe-to-Archive (creates archived conversations)
- **Story 8.11:** Undo Archive Toast (alternative unarchive method)
- **Story 8.12:** Archive Notification Behavior (mutes archived conversations)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 152-190)
