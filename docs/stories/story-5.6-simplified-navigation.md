# Story 5.6: Simplified Navigation

## Status
Draft

## Story
**As a** user,
**I want** clear and intuitive navigation,
**so that** I can easily access channels, DMs, and my profile.

## Acceptance Criteria

1. Fans see 3 tabs: Channels | DMs | Profile
2. Creator sees 3 tabs: Channels | Inbox | Profile (Settings tab deferred)
3. Tab bar is conditional based on userType
4. "New Group" button is removed (channels are pre-created)
5. "Message Andrew" button is accessible for fans in multiple locations
6. Primary "Message Andrew" location: Empty state in FanDMView
7. Secondary location: Floating action button (FAB) in ChannelsView
8. Tab icons are clear and appropriate (SF Symbols)
9. Active tab is visually distinct
10. Navigation is consistent throughout the app
11. Deep linking works for push notifications
12. Tab selection persists across app restarts

## Tasks / Subtasks

- [ ] Create MainTabView with conditional tabs (AC: 1, 2, 3)
  - [ ] Create MainTabView.swift file
  - [ ] Use @EnvironmentObject for current user
  - [ ] Conditionally display tabs based on user.userType
  - [ ] Set up TabView with proper tab items
  - [ ] Ensure tab selection state is managed

- [ ] Define fan navigation structure (AC: 1)
  - [ ] Tab 1: ChannelsView (list of channels)
  - [ ] Tab 2: FanDMView (conversation with Andrew)
  - [ ] Tab 3: ProfileView (user profile)
  - [ ] Choose appropriate SF Symbols for tab icons
  - [ ] Set tab labels

- [ ] Define creator navigation structure (AC: 2)
  - [ ] Tab 1: ChannelsView (same as fans)
  - [ ] Tab 2: InboxView (fan DMs inbox)
  - [ ] Tab 3: ProfileView (creator profile)
  - [ ] Settings tab deferred to future sprint
  - [ ] Choose appropriate SF Symbols for tab icons
  - [ ] Set tab labels

- [ ] Remove "New Group" button (AC: 4)
  - [ ] Remove from ChannelsView toolbar/header
  - [ ] Remove related action handlers
  - [ ] Clean up navigation to group creation flow
  - [ ] Document that channels are pre-seeded

- [ ] Add "Message Andrew" button for fans (AC: 5, 6, 7)
  - [ ] Primary: Show in FanDMView empty state if no DM with Andrew exists
  - [ ] Secondary: Add floating action button (FAB) in ChannelsView
  - [ ] Only show for fans (if !currentUser.isCreator)
  - [ ] On tap, call viewModel.createOrOpenDMWithAndrew()
  - [ ] Use SF Symbol "paperplane.fill" for FAB
  - [ ] Empty state button: "Message Andrew" with description

- [ ] Style tab bar (AC: 6, 7)
  - [ ] Select appropriate SF Symbol icons for each tab
  - [ ] Ensure icons are recognizable and clear
  - [ ] Use distinct colors for selected vs unselected
  - [ ] Add badge support for unread counts
  - [ ] Test on different screen sizes

- [ ] Test navigation consistency (AC: 8)
  - [ ] Verify all navigation flows work correctly
  - [ ] Check back navigation behaves as expected
  - [ ] Ensure modal presentations dismiss properly
  - [ ] Test NavigationStack state management

- [ ] Implement tab selection persistence (AC: 10)
  - [ ] Save selected tab index to UserDefaults
  - [ ] Restore selected tab on app launch
  - [ ] Handle edge cases (invalid tab index)
  - [ ] Ensure persistence works across updates

- [ ] Set up deep linking (AC: 9)
  - [ ] Handle push notification taps
  - [ ] Navigate to correct conversation from notification
  - [ ] Switch to correct tab if needed
  - [ ] Ensure deep link state is handled

## Dev Notes

### Architecture Context

**Tab Bar Structure:**
```swift
struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("selectedTab") private var selectedTab = 0

    var currentUser: UserEntity? {
        authService.currentUser
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Channels (Everyone)
            NavigationStack {
                ChannelsView()
            }
            .tabItem {
                Label("Channels", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            // Tab 2: Inbox (Creator) or DMs (Fan)
            NavigationStack {
                if currentUser?.isCreator == true {
                    InboxView()
                } else {
                    FanDMView()
                }
            }
            .tabItem {
                Label(
                    currentUser?.isCreator == true ? "Inbox" : "DMs",
                    systemImage: currentUser?.isCreator == true ? "tray" : "message"
                )
            }
            .badge(inboxUnreadCount)
            .tag(1)

            // Tab 3: Profile (Everyone)
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(2)
        }
    }
}
```

**Tab Icons (SF Symbols):**
- Channels: `bubble.left.and.bubble.right` or `number.square`
- Inbox (Creator): `tray` or `envelope`
- DMs (Fan): `message` or `bubble.left.and.bubble.right.fill`
- Profile: `person.circle` or `person.crop.circle`
- Message Andrew FAB: `paperplane.fill`

**Deep Linking Handler:**
```swift
struct BuzzboxApp: App {
    @StateObject private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authService)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    func handleDeepLink(_ url: URL) {
        // Parse URL and navigate to conversation
        // e.g., buzzbox://conversation/{conversationId}
    }
}
```

### Source Tree
```
Core/
├── Views/
│   ├── Main/
│   │   └── MainTabView.swift (NEW - Main tab navigation)
│   ├── Channels/
│   │   └── ChannelsView.swift (Update - remove new group button)
│   ├── Inbox/
│   │   ├── InboxView.swift (From Story 5.5)
│   │   └── FanDMView.swift (From Story 5.5)
│   └── Profile/
│       └── ProfileView.swift (Update - add Message Andrew button)
└── Utilities/
    └── DeepLinkHandler.swift (NEW - Handle deep links)
```

### User Experience Goals
- **Simplicity:** Minimal tabs, clear purpose for each
- **Clarity:** Tab labels and icons are self-explanatory
- **Efficiency:** Quick access to main features
- **Context-Aware:** Different navigation for creator vs fans
- **Consistency:** Same patterns throughout app

### Navigation Patterns
- **TabView:** Main app navigation (bottom tabs)
- **NavigationStack:** Within-tab navigation (push/pop)
- **Sheet:** Modals for settings, profile edit
- **Alert:** Confirmations, errors
- **Toast:** Quick feedback (using PopupView)

### Dependencies
- **Depends on:** Story 5.2 (User Type) - Conditional tabs
- **Depends on:** Story 5.3 (Channel System) - Channels tab
- **Depends on:** Story 5.5 (Creator Inbox) - Inbox/DM tabs
- **Completes:** Epic 5 - Final piece of architecture pivot

## Testing

### Testing Standards
- Manual testing on simulator and device
- Test with both fan and creator accounts
- Test tab switching and navigation
- Verify persistence across app restarts
- Test deep linking from notifications

### Test Cases

1. **Fan Tab Bar:**
   - Login as fan
   - Verify 3 tabs visible: Channels | DMs | Profile
   - Check tab icons are correct
   - Verify tab labels match expected text
   - No Settings tab visible

2. **Creator Tab Bar:**
   - Login as Andrew (creator)
   - Verify 3 tabs visible: Channels | Inbox | Profile
   - Settings tab may be visible (future)
   - Check tab icons are correct
   - Inbox shows unread badge if applicable

3. **Tab Selection:**
   - Tap each tab
   - Verify correct view displays
   - Check active tab is visually highlighted
   - Tap same tab again (should scroll to top if applicable)

4. **Tab Persistence:**
   - Select tab 2 (DMs/Inbox)
   - Force quit app
   - Relaunch app
   - Verify tab 2 is still selected

5. **Message Andrew Button (Fans):**
   - Login as fan
   - Navigate to Profile or DMs tab
   - Find "Message Andrew" button
   - Tap button
   - Verify DM with Andrew opens or is created

6. **No New Group Button:**
   - Navigate to Channels tab
   - Verify no "New Group" or "+" button exists
   - Confirm channels cannot be created by users
   - Only pre-seeded channels visible

7. **Navigation Consistency:**
   - Navigate from Channels → Channel thread
   - Use back button → returns to Channels
   - Navigate from Inbox → Message thread
   - Use back button → returns to Inbox
   - Verify navigation stack behaves correctly

8. **Deep Linking:**
   - Receive push notification for new message
   - Tap notification
   - App opens to correct conversation
   - Correct tab is selected
   - Conversation is visible

9. **Unread Badges:**
   - Have unread messages in DMs/Inbox
   - Check badge appears on DMs/Inbox tab
   - Badge shows correct count
   - Open conversation
   - Badge decreases or disappears

10. **User Type Switching:**
    - Login as fan
    - Verify fan tabs
    - Logout
    - Login as creator
    - Verify creator tabs
    - Check no visual glitches

11. **Edge Cases:**
    - Delete all conversations
    - Verify empty states in each tab
    - Create new conversation
    - Verify tab updates
    - Test with slow network

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
