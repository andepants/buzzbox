# Story 8.6: Creator Inbox Smart Filter (AI Category)

**Epic:** Epic 8 - Premium UX Polish & Demo-Ready Features
**Phase:** Phase 2 - Interactive Polish
**Priority:** P1 (High - UX enhancement)
**Effort:** 3.5 hours
**Status:** Ready for Development

---

## Goal

Enable filtering of conversations in the Creator Inbox by AI-detected category (All, Fan, Super Fan, Business, Spam, Urgent).

---

## User Story

**As** Andrew (The Creator),
**I want** to filter my inbox by AI-detected conversation categories,
**So that** I can focus on specific types of conversations (urgent, business, fans, etc.).

---

## Dependencies

- ✅ **Epic 6:** AI Features (provides `ConversationEntity.aiCategory` property)
- ✅ Existing InboxView structure

---

## Implementation

### AICategory Enum

Create `buzzbox/Core/Models/AICategory.swift`:

```swift
enum AICategory: String, CaseIterable, Codable {
    case all = "all"
    case fan = "fan"
    case superFan = "super_fan"
    case business = "business"
    case spam = "spam"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .fan: return "Fan"
        case .superFan: return "Super Fan"
        case .business: return "Business"
        case .spam: return "Spam"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.fill"
        case .fan: return "heart.fill"
        case .superFan: return "star.fill"
        case .business: return "briefcase.fill"
        case .spam: return "trash.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .fan: return .pink
        case .superFan: return .purple
        case .business: return .green
        case .spam: return .red
        case .urgent: return .orange
        }
    }

    /// Validate raw string from AI against enum cases
    static func validate(_ rawValue: String?) -> AICategory? {
        guard let raw = rawValue else { return nil }
        return AICategory(rawValue: raw)
    }
}
```

### FilterChipView Component

Create `buzzbox/Core/Views/Components/FilterChipView.swift`:

```swift
struct FilterChipView: View {
    let category: AICategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticFeedback.impact(.light)
        }) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : Color.gray.opacity(0.15))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
```

### InboxView Filter Implementation

Update `InboxView.swift`:

```swift
struct InboxView: View {
    @State private var selectedCategory: AICategory = .all
    @State private var searchText = ""

    var filteredConversations: [ConversationEntity] {
        // Step 1: Apply search filter
        let searchFiltered = searchText.isEmpty
            ? dmConversations
            : dmConversations.filter { conversation in
                // Search by participant name or last message
                conversation.otherParticipant?.displayName
                    .localizedCaseInsensitiveContains(searchText) ?? false
            }

        // Step 2: Apply category filter with nil handling
        if selectedCategory == .all {
            return searchFiltered
        } else {
            return searchFiltered.filter { conversation in
                guard let category = conversation.aiCategory else { return false }
                guard let validCategory = AICategory.validate(category) else { return false }
                return validCategory == selectedCategory
            }
        }
    }

    var categoryCounts: [AICategory: Int] {
        var counts: [AICategory: Int] = [:]

        for category in AICategory.allCases {
            if category == .all {
                counts[category] = dmConversations.count
            } else {
                counts[category] = dmConversations.filter { conversation in
                    guard let cat = conversation.aiCategory else { return false }
                    return AICategory.validate(cat) == category
                }.count
            }
        }

        return counts
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AICategory.allCases, id: \.self) { category in
                            FilterChipView(
                                category: category,
                                count: categoryCounts[category] ?? 0,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))

                // Conversation List
                if filteredConversations.isEmpty {
                    emptyFilterState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Inbox")
        }
        .searchable(text: $searchText, prompt: "Search conversations")
    }

    private var emptyFilterState: some View {
        ContentUnavailableView(
            "No \(selectedCategory.displayName.lowercased()) conversations",
            systemImage: selectedCategory.icon,
            description: Text("Try selecting a different category")
        )
    }
}
```

---

## Acceptance Criteria

### Functional Requirements
- ✅ Filter chips appear horizontally scrollable at top of inbox
- ✅ Tapping filter animates selection (spring bounce)
- ✅ Conversations filter by selected category
- ✅ Count badges show number of conversations per category
- ✅ "All" shows total count
- ✅ Filter persists during search

### Visual Requirements
- ✅ Chips have icon + label + count badge
- ✅ Selected chip highlighted with category color
- ✅ Unselected chips have gray background
- ✅ Smooth spring animation on selection
- ✅ Horizontal scroll for chip overflow

### Filter Logic Requirements
- ✅ Filter + Search use AND logic (not OR)
- ✅ Null categories only appear in "All" filter
- ✅ Invalid AI categories ignored (validation)

---

## Edge Cases & Error Handling

### Null Categories
- ✅ **Behavior:** Conversations with `aiCategory == nil` only appear in "All" filter
- ✅ **Implementation:** Guard check in filter logic

### Invalid Categories from AI
- ✅ **Behavior:** Validate against enum, ignore invalid values
- ✅ **Implementation:** `AICategory.validate()` static method

### Filter + Search AND Logic
- ✅ **Behavior:** Search within filtered results, not OR
- ✅ **Implementation:** Two-step filter (search first, then category)

### Empty Filter State
- ✅ **Behavior:** Shows "No [category] conversations" when filter has no results
- ✅ **Implementation:** ContentUnavailableView with category-specific message

### Pinned Conversations
- ✅ **Behavior:** Respect filter (don't always show pinned)
- ✅ **Implementation:** Apply filter to all conversations, including pinned

### Real-time Updates
- ✅ **Behavior:** New message changes category → smooth animation in/out of filter
- ✅ **Implementation:** SwiftData `@Query` auto-updates, animation via `withAnimation`

### Scroll Position Maintenance
- ✅ **Behavior:** Maintain scroll position when filter updates
- ✅ **Implementation:** Use `.id()` modifier on List with stable IDs

---

## Files to Create

### New Enum
- `buzzbox/Core/Models/AICategory.swift`
  - Enum with cases (all, fan, superFan, business, spam, urgent)
  - Display names, icons, colors
  - Validation method

### New Component
- `buzzbox/Core/Views/Components/FilterChipView.swift`
  - Chip UI with icon, label, count
  - Selected/unselected states
  - Haptic feedback on tap

---

## Files to Modify

### Primary Files
- `buzzbox/Features/Inbox/Views/InboxView.swift`
  - Add filter chip ScrollView
  - Add `selectedCategory` state
  - Update `filteredConversations` computed property
  - Add `categoryCounts` computed property
  - Add empty filter state view

---

## Technical Notes

### SwiftData Auto-Updates

`@Query` automatically updates when conversation categories change:
```swift
@Query private var dmConversations: [ConversationEntity]
```

No manual refresh needed.

### Filter AND Logic

Search + Filter must use AND logic:
```swift
// Step 1: Filter by search
let searchFiltered = /* ... */

// Step 2: Filter by category (within search results)
if selectedCategory != .all {
    return searchFiltered.filter { /* category logic */ }
}
```

### Spring Animation

Use spring animation for smooth selection:
```swift
withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
    selectedCategory = category
}
```

### Count Badge Performance

Calculate counts once per render using computed property:
```swift
var categoryCounts: [AICategory: Int] {
    // Calculate all counts
}
```

---

## Testing Checklist

### Functional Testing
- [ ] Filter chips appear at top of inbox
- [ ] Tap "Fan" → only fan conversations shown
- [ ] Tap "Business" → only business conversations shown
- [ ] Tap "All" → all conversations shown
- [ ] Count badges show correct numbers
- [ ] Search + Filter works together (AND logic)

### Visual Testing
- [ ] Selected chip highlights with category color
- [ ] Unselected chips have gray background
- [ ] Spring animation on selection
- [ ] Chips scroll horizontally when overflow
- [ ] Count badges positioned correctly

### Edge Case Testing
- [ ] Conversations with `aiCategory = nil` → only in "All"
- [ ] AI returns invalid category → ignored
- [ ] Filter with 0 results → empty state shows
- [ ] New message changes category → smooth animation
- [ ] Rapid filter toggling → no glitches

### Performance Testing
- [ ] Calculate counts with 100+ conversations → smooth
- [ ] Filter with large dataset → instant results
- [ ] Scroll position maintained during filter change

---

## Definition of Done

- ✅ AICategory enum created with validation
- ✅ FilterChipView component created
- ✅ Filter chips display at top of inbox
- ✅ Tapping chip filters conversations
- ✅ Count badges show correct numbers
- ✅ Spring animation implemented
- ✅ AND logic for filter + search
- ✅ Null category handling works
- ✅ Invalid category validation works
- ✅ Empty filter state implemented
- ✅ Real-time updates working
- ✅ VoiceOver accessibility verified
- ✅ No performance issues with large datasets

---

## Related Stories

- **Epic 6:** AI Features (provides aiCategory property)
- **Story 8.10:** Enhanced Haptics (uses same haptic feedback)

---

**Created:** 2025-10-25
**Epic Source:** `docs/prd/epic-8-premium-ux-polish.md` (Lines 336-412)
