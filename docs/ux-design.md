# Sorted - UX/UI Specifications

**Version:** 1.0
**Last Updated:** October 20, 2025
**Platform:** iOS 17+ (SwiftUI)
**Design Language:** Native iOS with AI-Enhanced Features

---

## Table of Contents

1. [Overall UX Goals & Principles](#1-overall-ux-goals--principles)
2. [Information Architecture](#2-information-architecture)
3. [Design System](#3-design-system)
4. [Screen Specifications](#4-screen-specifications)
5. [AI Feature UI Patterns](#5-ai-feature-ui-patterns)
6. [Interaction Patterns](#6-interaction-patterns)
7. [Offline UI Patterns](#7-offline-ui-patterns)
8. [Accessibility Considerations](#8-accessibility-considerations)
9. [Animation & Transitions](#9-animation--transitions)

---

## 1. Overall UX Goals & Principles

### 1.1 Target User Persona

**Primary: Content Creator ("Alex")**
- **Profile:** 25-35 years old, YouTuber/TikToker with 100K-1M followers
- **Pain Points:** Drowning in 200+ DMs daily, missing business opportunities, wants authentic engagement
- **Tech Savvy:** Comfortable with iOS, expects smooth native experiences
- **Goals:** Quickly triage messages, respond authentically, identify business opportunities
- **Context:** Often on-the-go, using phone with one hand, multitasking

### 1.2 Key Usability Goals

1. **Speed to Value:** User can triage 50+ messages in under 5 minutes
2. **AI Transparency:** AI features feel helpful, not intrusive; always editable
3. **Offline Resilience:** App works seamlessly offline without user noticing gaps
4. **One-Handed Use:** All core actions accessible with thumb on iPhone 14/15
5. **Learning Curve:** New users understand core features within first 2 minutes

### 1.3 Core Design Principles

1. **Native iOS First** - No web-style interfaces; leverage iOS design patterns users know
2. **AI as Copilot, Not Autopilot** - AI suggests, user decides; never auto-send
3. **Progressive Disclosure** - Show complexity only when needed; start simple
4. **Offline-First Mindset** - Design for "what if there's no network?" first
5. **Delight in Speed** - Prioritize instant feedback and perceived performance

---

## 2. Information Architecture

### 2.1 Navigation Structure

**Primary Navigation:** iOS TabView (Bottom Bar)

```
┌─────────────────────────────┐
│     Sorted               │
├─────────────────────────────┤
│                             │
│    [Screen Content]         │
│                             │
│                             │
├─────────────────────────────┤
│  💬    🎯    📊    👤      │
│  All  Priority  Biz   Me    │
└─────────────────────────────┘
```

**Tab Structure:**

1. **All Messages** (💬)
   - Default view: Conversation list sorted by recency
   - Smart categories visible as filters

2. **Priority** (🎯)
   - Urgent/negative sentiment messages
   - Requires immediate attention

3. **Business** (📊)
   - Business opportunities
   - Sorted by opportunity score

4. **Profile** (👤)
   - Settings, FAQ library, account

### 2.2 Screen Hierarchy

```
Root (TabView)
├── All Messages Tab
│   ├── Conversation List View
│   │   └── Message Thread View
│   │       ├── Message Detail (contextual)
│   │       └── Draft Reply Sheet
│   └── New Message Sheet
│       └── Contact Picker
│
├── Priority Tab
│   └── Priority Inbox View
│       └── Message Thread View (shared)
│
├── Business Tab
│   └── Business Opportunities View
│       └── Message Thread View (shared)
│           └── Opportunity Detail Card
│
└── Profile Tab
    ├── Settings View
    ├── FAQ Library View
    │   └── FAQ Edit Sheet
    ├── Notifications Settings
    └── Account Management
```

### 2.3 Key User Flows

**Flow 1: Quick Message Triage (Primary Use Case)**
```
1. Open app → All Messages Tab
2. Scan conversation list (AI categories visible)
3. Tap conversation
4. Read messages + AI insights (category badge, sentiment)
5. If actionable: Tap "Draft Reply" → Review → Send
6. If FAQ: Tap suggested answer → Send
7. Swipe back → Next conversation
```

**Flow 2: Respond to Business Opportunity**
```
1. Open Business Tab
2. See opportunities sorted by score
3. Tap high-scoring opportunity
4. Review opportunity score breakdown
5. Read conversation history
6. Draft reply (AI uses context)
7. Send response
```

**Flow 3: Manage FAQs**
```
1. Profile Tab → FAQ Library
2. Tap "Add FAQ"
3. Select category
4. Enter question pattern + answer
5. Save
6. FAQ now available for auto-detection
```

---

## 3. Design System

### 3.1 Color Palette

**System Colors (Adapts to Dark/Light Mode)**

| Purpose | Light Mode | Dark Mode | Usage |
|---------|-----------|-----------|--------|
| Primary | iOS Blue (#007AFF) | iOS Blue (#0A84FF) | Actions, links, selection |
| Background | White (#FFFFFF) | Black (#000000) | Main background |
| Secondary BG | Gray 6 (#F2F2F7) | Gray 1 (#1C1C1E) | Cards, grouped lists |
| Tertiary BG | Gray 5 (#E5E5EA) | Gray 2 (#2C2C2E) | Input fields, elevated surfaces |

**Semantic Colors**

| Purpose | Light Mode | Dark Mode | Usage |
|---------|-----------|-----------|--------|
| Success | Green (#34C759) | Green (#32D74B) | Sent status, positive sentiment |
| Warning | Orange (#FF9500) | Orange (#FF9F0A) | Neutral sentiment, warnings |
| Error | Red (#FF3B30) | Red (#FF453A) | Failed sends, urgent sentiment |
| Info | Blue (#007AFF) | Blue (#0A84FF) | Business messages, info badges |

**AI Feature Colors**

| Feature | Color | Usage |
|---------|-------|--------|
| AI Suggestion | Purple (#AF52DE → #BF5AF2) | Draft reply cards, AI badges |
| Category: Fan | Pink (#FF2D55 → #FF375F) | Fan message badge |
| Category: Business | Blue (#007AFF → #0A84FF) | Business message badge |
| Category: Spam | Gray (#8E8E93) | Spam message badge |
| Sentiment: Urgent | Red (#FF3B30 → #FF453A) | Urgent flag |
| Opportunity Score | Gold (#FFCC00 → #FFD60A) | High-value badge (80+) |

### 3.2 Typography

**System Font: SF Pro (iOS Native)**

| Element | Size | Weight | Line Height | Usage |
|---------|------|--------|-------------|--------|
| Large Title | 34pt | Bold | 41pt | Screen titles |
| Title 1 | 28pt | Bold | 34pt | Section headers |
| Title 2 | 22pt | Bold | 28pt | Card titles |
| Title 3 | 20pt | Semibold | 25pt | List headers |
| Headline | 17pt | Semibold | 22pt | Emphasized text |
| Body | 17pt | Regular | 22pt | Main content, messages |
| Callout | 16pt | Regular | 21pt | Secondary info |
| Subheadline | 15pt | Regular | 20pt | Timestamps, metadata |
| Footnote | 13pt | Regular | 18pt | Captions, helper text |
| Caption 1 | 12pt | Regular | 16pt | Tiny labels |
| Caption 2 | 11pt | Regular | 13pt | Ultra-small labels |

**Dynamic Type Support:** All text scales with user's accessibility settings.

### 3.3 Spacing System

**8pt Grid System**

```
4pt  - Minimum spacing (tight)
8pt  - Default spacing (standard)
12pt - Small spacing
16pt - Medium spacing
20pt - Large spacing
24pt - XL spacing
32pt - XXL spacing
40pt - Section spacing
```

**Component Padding:**
- List items: 16pt vertical, 16pt horizontal
- Cards: 16pt all sides
- Buttons: 12pt vertical, 20pt horizontal
- Input fields: 12pt vertical, 16pt horizontal

### 3.4 Iconography

**SF Symbols (iOS Native)**

| Purpose | Icon | Variants |
|---------|------|----------|
| Messages | message.fill | message, message.badge |
| Priority | exclamationmark.triangle.fill | flag.fill |
| Business | briefcase.fill | chart.line.uptrend.xyaxis |
| Profile | person.circle.fill | person.crop.circle |
| Send | paperplane.fill | paperplane |
| Draft | pencil.circle.fill | doc.text |
| FAQ | questionmark.circle.fill | book.fill |
| AI | sparkles | wand.and.stars |
| Category | tag.fill | tag.circle.fill |
| Sentiment | face.smiling.fill | face.dashed.fill |
| Score | star.fill | star.leadinghalf.filled |
| Search | magnifyingglass | magnifyingglass.circle.fill |
| Filter | line.3.horizontal.decrease.circle | slider.horizontal.3 |
| Settings | gearshape.fill | gearshape.2.fill |
| New Message | square.and.pencil | plus.circle.fill |
| Delete | trash.fill | xmark.circle.fill |
| Edit | pencil | pencil.circle |

**Icon Sizes:**
- Tab Bar: 28x28pt
- List Items: 20x20pt
- Buttons: 22x22pt
- Badges: 16x16pt

### 3.5 Component Library

**Core SwiftUI Components:**

1. **MessageBubble** - Custom chat bubble
2. **ConversationRow** - List item with preview
3. **CategoryBadge** - AI category pill
4. **SentimentIndicator** - Emotional tone badge
5. **DraftReplyCard** - AI suggestion card
6. **OpportunityScoreView** - Business score display
7. **FAQSuggestionCard** - Auto-responder suggestion
8. **LoadingState** - Activity indicators
9. **EmptyState** - No content placeholder
10. **ErrorBanner** - Error messages
11. **OfflineIndicator** - Connection status
12. **TypingIndicator** - Live typing animation

---

## 4. Screen Specifications

### 4.1 Onboarding Flow

**Screen 1: Welcome**

```
┌─────────────────────────────┐
│                             │
│     [App Icon - Large]      │
│                             │
│      Sorted              │
│   AI-Powered Messaging      │
│   for Content Creators      │
│                             │
│  • Smart Categorization     │
│  • Auto-Draft Replies       │
│  • Business Opportunity     │
│    Detection                │
│                             │
│  [Get Started - Primary]    │
│  [Sign In - Secondary]      │
│                             │
└─────────────────────────────┘
```

**SwiftUI Components:**
- `VStack` with centered content
- `Image(systemName: "sparkles")` for icon decoration
- `Text` with `.title` and `.headline` styles
- `Button` with `.buttonStyle(.borderedProminent)`

**States:**
- Default (as shown)
- Loading (after button tap)

**Interactions:**
- Tap "Get Started" → Phone number entry
- Tap "Sign In" → Login flow
- Can skip with "Skip Tour" (shown after 2 seconds)

---

**Screen 2: Permissions Request**

```
┌─────────────────────────────┐
│                             │
│  [Icon: bell.badge.fill]    │
│                             │
│  Enable Notifications       │
│                             │
│  Get instant alerts when    │
│  urgent messages arrive     │
│  or business opportunities  │
│  are detected.              │
│                             │
│  [Enable - Primary]         │
│  [Maybe Later - Text]       │
│                             │
└─────────────────────────────┘
```

**SwiftUI Components:**
- Similar to Welcome screen
- System permission alert triggered by button

**Permissions Flow:**
1. Notifications (this screen)
2. Contacts (if needed for contact picker)

---

**Screen 3: AI Features Tour (Carousel)**

```
┌─────────────────────────────┐
│  ● ○ ○ ○ ○  (Page dots)    │
│                             │
│  [Illustration: Categories] │
│                             │
│  Smart Categories           │
│                             │
│  Messages automatically     │
│  sorted into Fan, Business, │
│  and Priority inboxes.      │
│                             │
│  [Next]                     │
│  Skip                       │
└─────────────────────────────┘
```

**5 Carousel Pages:**
1. Smart Categories
2. AI-Drafted Replies
3. FAQ Auto-Responder
4. Sentiment Analysis
5. Business Opportunities

**SwiftUI Components:**
- `TabView` with `.tabViewStyle(.page)`
- Custom illustrations (SF Symbols compositions)
- Skip button always visible

---

### 4.2 All Messages Tab

**Conversation List View**

```
┌─────────────────────────────┐
│  All Messages        [+]    │
│                             │
│  ┌─ Filter Pills ─────────┐ │
│  │ All │ Fan │ Biz │ Spam ││ │
│  └────────────────────────┘ │
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Sarah Johnson  ││
│  │ That's awesome! Can't...││
│  │ [💬Fan] • 2m ago   [1] ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] BrandCo        ││
│  │ Interested in collabor..││
│  │ [💼Biz 87] • 1h ago     ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Group Chat     ││
│  │ Mike: See you there! ... ││
│  │ 12m ago            [3]  ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**SwiftUI Structure:**
```swift
NavigationStack {
    List {
        // Filter Pills
        ScrollView(.horizontal) {
            HStack {
                FilterPill("All", selected: true)
                FilterPill("Fan")
                FilterPill("Business")
                FilterPill("Spam")
            }
        }
        .listRowInsets(EdgeInsets())

        // Conversations
        ForEach(conversations) { conversation in
            NavigationLink(destination: MessageThreadView(conversation)) {
                ConversationRow(conversation)
            }
        }
    }
    .navigationTitle("All Messages")
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showNewMessage = true }) {
                Image(systemName: "square.and.pencil")
            }
        }
    }
}
```

**ConversationRow Component:**
- **Layout:** HStack with Avatar (48x48pt), VStack (name, preview, metadata), Spacer, Badge
- **Avatar:** AsyncImage with fallback initials
- **Name:** Text, `.headline` weight, 1 line max
- **Preview:** Text, `.subheadline`, gray, 2 lines max
- **Metadata:** HStack with category badge, timestamp, unread count
- **Category Badge:** Capsule with icon + text (e.g., "💼 Biz 87")

**States:**
1. **Default** - As shown
2. **Unread** - Bold name, blue dot, unread count
3. **Sending** - Spinner next to last message
4. **Failed** - Red error badge
5. **Offline** - Gray "Queued" badge
6. **Empty** - EmptyStateView (no conversations)
7. **Loading** - Skeleton loaders

**Interactions:**
- **Tap Row** → Navigate to Message Thread
- **Swipe Right** → Mark as read/unread
- **Swipe Left** → Delete, Archive, Mute (destructive trailing swipe)
- **Long Press** → Context menu (Pin, Mute, Delete)
- **Tap Filter Pill** → Filter list by category
- **Pull to Refresh** → Sync with server
- **Tap [+]** → New Message Sheet

**Animations:**
- List items fade in on load
- Swipe actions reveal with spring animation
- Filter pill selection highlights with scale effect
- Pull to refresh indicator

---

### 4.3 Message Thread View

**Thread Layout**

```
┌─────────────────────────────┐
│ < Sarah Johnson      [...]  │
│   [💬Fan] Active now        │
├─────────────────────────────┤
│                             │
│         Hey! Loved your     │
│         latest video 🎬     │
│         [Gray Bubble]       │
│         2:34 PM             │
│                             │
│  That's awesome!            │
│  Thanks so much!            │
│  [Blue Bubble]              │
│  2:35 PM ✓✓                │
│                             │
│         Can't wait for      │
│         the next one!       │
│         [Gray Bubble]       │
│         Just now            │
│                             │
│  ┌──AI Draft Reply────────┐ │
│  │ ✨ Suggested Reply      │ │
│  │ "Thank you! I'm working │ │
│  │ on something special... │ │
│  │ [Edit] [Send]          │ │
│  └────────────────────────┘ │
│                             │
├─────────────────────────────┤
│ [+] Type a message...  [↑] │
└─────────────────────────────┘
```

**SwiftUI Structure:**
```swift
NavigationStack {
    VStack(spacing: 0) {
        // Messages ScrollView
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message)
                            .id(message.id)
                    }

                    // AI Draft Card (if available)
                    if let draft = aiDraft {
                        DraftReplyCard(draft)
                    }
                }
                .padding()
            }
        }

        // Input Bar
        MessageInputBar(text: $messageText)
    }
    .navigationTitle(conversation.name)
    .navigationBarTitleDisplayMode(.inline)
}
```

**MessageBubble Component:**
- **Sent (Right-aligned):** Blue bubble, white text, HStack with Spacer first
- **Received (Left-aligned):** Gray bubble, black text, HStack with Spacer last
- **Tail:** Subtle rounded tail pointing to sender
- **Timestamp:** Below bubble, small gray text
- **Status:** For sent messages: Sending (spinner), Sent (✓), Delivered (✓✓), Read (✓✓ blue)
- **Max Width:** 75% of screen width
- **Padding:** 12pt vertical, 16pt horizontal

**DraftReplyCard Component:**
```
┌────────────────────────────┐
│ ✨ AI-Drafted Reply        │
│                            │
│ "Thank you so much! I'm    │
│ really excited to share... │
│                            │
│ [✏️ Edit] [📨 Send]       │
└────────────────────────────┘
```

**States:**
1. **Default** - Messages loaded
2. **Loading** - Skeleton bubbles
3. **Typing Indicator** - Animated dots in gray bubble
4. **Sending Message** - Bubble with spinner
5. **Failed Send** - Bubble with red badge + retry button
6. **Empty Thread** - EmptyStateView
7. **AI Processing** - "Analyzing message..." indicator

**Interactions:**
- **Tap Message** → Show timestamp + status
- **Long Press Message** → Copy, React, Delete
- **Tap Avatar** → View profile
- **Tap Category Badge** → Show category info
- **Tap AI Draft** → Expand to full editing sheet
- **Tap "Edit" on Draft** → Open MessageInputBar with pre-filled text
- **Tap "Send" on Draft** → Send as-is
- **Swipe Down** → Dismiss keyboard
- **Pull to Refresh** → Load older messages

**Animations:**
- New messages slide in from bottom
- Typing indicator pulses
- Send button grows when text entered
- Draft card slides up when available

---

### 4.4 Priority Tab

**Priority Inbox View**

```
┌─────────────────────────────┐
│  Priority Inbox      🎯     │
│                             │
│  Urgent & High-Priority     │
│  messages requiring         │
│  immediate attention        │
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Mike Chen      ││
│  │ Hey, I need help with...││
│  │ [🚨Urgent] • 5m ago [!]││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Jamie Lee      ││
│  │ I'm really frustrated...││
│  │ [😰Negative] • 30m ago  ││
│  └─────────────────────────┘│
│                             │
│  [Empty state if none]      │
│                             │
└─────────────────────────────┘
```

**SwiftUI Structure:**
- Similar to All Messages List
- Filtered to show only urgent/negative high-intensity
- Red accent color for urgent messages
- Sorted by urgency score (highest first)

**EmptyState:**
```
┌─────────────────────────────┐
│                             │
│   [Icon: checkmark.circle]  │
│                             │
│   All Caught Up!            │
│                             │
│   No urgent messages        │
│   need your attention.      │
│                             │
└─────────────────────────────┘
```

**Interactions:**
- Same as All Messages rows
- Swipe actions: Dismiss from Priority, Respond, Delete

---

### 4.5 Business Tab

**Business Opportunities View**

```
┌─────────────────────────────┐
│  Business              💼   │
│                             │
│  ┌─ Sort By ─────────────┐  │
│  │ Score │ Recent │ Value││  │
│  └──────────────────────┘  │
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] TechBrand Inc  ││
│  │ Interested in a paid... ││
│  │ [⭐ 92] $5K • 2h ago    ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Marketing Co   ││
│  │ We'd love to partner... ││
│  │ [⭐ 78] Est. $2K • 1d  ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ [Avatar] Startup XYZ    ││
│  │ Quick question about... ││
│  │ [⭐ 45] • 3d ago        ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**Opportunity Score Badge:**
- **90-100:** Gold star, "⭐ 92"
- **70-89:** Blue star, "⭐ 78"
- **50-69:** Gray star, "⭐ 45"
- **Below 50:** No star badge shown

**Opportunity Detail Card (in Thread):**
```
┌────────────────────────────┐
│ 💼 Opportunity Analysis    │
├────────────────────────────┤
│ Score: 92/100              │
│                            │
│ Monetary Value: 40/40 ⭐   │
│ Brand Fit: 28/30 ⭐        │
│ Legitimacy: 18/20 ⭐       │
│ Urgency: 6/10              │
│                            │
│ Why This Scores High:      │
│ • Specific budget mentioned│
│ • Verified brand (500K+)   │
│ • Strong product alignment │
│ • Time-sensitive offer     │
│                            │
│ [View Full Message ↓]     │
└────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct OpportunityScoreView: View {
    let score: OpportunityScore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            // Score breakdown
            // Reasoning
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
```

**Interactions:**
- **Tap Row** → Open thread with opportunity card visible
- **Tap Score** → Expand to see breakdown
- **Swipe Left** → Dismiss, Not Interested
- **Sort By Filters** → Re-order list

---

### 4.6 Profile Tab

**Profile/Settings View**

```
┌─────────────────────────────┐
│  Profile                    │
│                             │
│  ┌───────────────────────┐  │
│  │   [Large Avatar]      │  │
│  │   Alex Creator        │  │
│  │   alex@example.com    │  │
│  │   [Edit Profile]      │  │
│  └───────────────────────┘  │
│                             │
│  AI Features                │
│  ┌─────────────────────────┐│
│  │ FAQ Library         [>]││
│  │ Smart Reply Settings[>]││
│  │ Category Preferences[>]││
│  └─────────────────────────┘│
│                             │
│  General                    │
│  ┌─────────────────────────┐│
│  │ Notifications       [>]││
│  │ Privacy             [>]││
│  │ Help & Support      [>]││
│  │ About Sorted     [>]││
│  └─────────────────────────┘│
│                             │
│  [Sign Out]                 │
└─────────────────────────────┘
```

**SwiftUI Structure:**
```swift
List {
    // Profile Header
    Section {
        ProfileHeaderView(user)
    }

    // AI Features
    Section("AI Features") {
        NavigationLink("FAQ Library") { FAQLibraryView() }
        NavigationLink("Smart Reply Settings") { ReplySettingsView() }
        NavigationLink("Category Preferences") { CategorySettingsView() }
    }

    // General
    Section("General") {
        NavigationLink("Notifications") { NotificationSettingsView() }
        NavigationLink("Privacy") { PrivacySettingsView() }
        NavigationLink("Help & Support") { HelpView() }
        NavigationLink("About") { AboutView() }
    }

    // Sign Out
    Section {
        Button("Sign Out", role: .destructive) { signOut() }
    }
}
.listStyle(.insetGrouped)
```

---

**FAQ Library View**

```
┌─────────────────────────────┐
│ < FAQ Library         [+]   │
│                             │
│  Equipment                  │
│  ┌─────────────────────────┐│
│  │ What camera do you use? ││
│  │ I use a Sony A7III...   ││
│  │ Used 12 times       [>]││
│  └─────────────────────────┘│
│                             │
│  Business                   │
│  ┌─────────────────────────┐│
│  │ How can I work with you?││
│  │ Email me at...          ││
│  │ Used 8 times        [>]││
│  └─────────────────────────┘│
│                             │
│  Career                     │
│  ┌─────────────────────────┐│
│  │ How did you get started?││
│  │ I started in 2019...    ││
│  │ Used 23 times       [>]││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**FAQ Edit Sheet:**
```
┌─────────────────────────────┐
│ < New FAQ           [Save]  │
│                             │
│  Category                   │
│  [Equipment ▼]              │
│                             │
│  Question Pattern           │
│  ┌─────────────────────────┐│
│  │ What camera do you use? ││
│  └─────────────────────────┘│
│                             │
│  Answer                     │
│  ┌─────────────────────────┐│
│  │ I use a Sony A7III with ││
│  │ a 24-70mm lens. I love  ││
│  │ the low-light...        ││
│  │                         ││
│  └─────────────────────────┘│
│                             │
│  [Delete FAQ]               │
│                             │
└─────────────────────────────┘
```

**SwiftUI Components:**
- List with sections by category
- Sheet presentation for add/edit
- TextField for question
- TextEditor for answer
- Picker for category selection

---

## 5. AI Feature UI Patterns

### 5.1 Category Badge Design

**Visual Style:**
```
┌──────────────┐
│ 💬 Fan       │  ← Capsule shape, colored background
└──────────────┘
```

**Variants:**
- **Fan:** Pink background, heart icon, "💬 Fan"
- **Business:** Blue background, briefcase icon, "💼 Biz 87" (with score)
- **Spam:** Gray background, crossed icon, "🚫 Spam"
- **Urgent:** Red background, alert icon, "🚨 Urgent"

**SwiftUI Component:**
```swift
struct CategoryBadge: View {
    let category: MessageCategory
    let score: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.displayName)
            if let score = score {
                Text("\\(score)")
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.2))
        .foregroundColor(category.color)
        .clipShape(Capsule())
    }
}
```

**Placement:**
- Conversation List: Below preview text
- Message Thread: In navigation bar subtitle
- Message Bubble: Optional badge for first message in category

---

### 5.2 AI Draft Reply Card

**Card Design:**
```
┌────────────────────────────────┐
│ ✨ AI-Drafted Reply            │
│                                │
│ "Thank you so much! I'm really │
│ excited to share what I'm      │
│ working on next. Stay tuned!"  │
│                                │
│ ┌─────────────┬──────────────┐ │
│ │ ✏️ Edit     │ 📨 Send     │ │
│ └─────────────┴──────────────┘ │
│                                │
│ [👎 Dismiss]                   │
└────────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct DraftReplyCard: View {
    let draft: String
    let onEdit: () -> Void
    let onSend: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI-Drafted Reply", systemImage: "sparkles")
                .font(.subheadline)
                .foregroundColor(.purple)

            Text(draft)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button(action: onSend) {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Dismiss", action: onDismiss)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}
```

**Interactions:**
- **Tap "Edit"** → Dismiss card, load text into input bar
- **Tap "Send"** → Send immediately, show confirmation
- **Tap "Dismiss"** → Remove card with slide-down animation
- **Long Press** → Show options: "Edit", "Copy", "Report Issue"

**States:**
- **Loading:** Show spinner with "Drafting reply..."
- **Error:** Show "Failed to generate" with retry button
- **Success:** Show card as designed

---

### 5.3 FAQ Suggestion Card

**Card Design:**
```
┌────────────────────────────────┐
│ ❓ Suggested FAQ Answer        │
│                                │
│ Question Detected:             │
│ "What camera do you use?"      │
│                                │
│ Your Answer:                   │
│ "I use a Sony A7III with a     │
│ 24-70mm lens..."               │
│                                │
│ ┌─────────────┬──────────────┐ │
│ │ ✏️ Edit     │ 📨 Send     │ │
│ └─────────────┴──────────────┘ │
│                                │
│ [Not This Time]                │
└────────────────────────────────┘
```

**Similar to Draft Card, but:**
- Blue accent color (vs. purple)
- Shows detected question
- Confidence indicator: "High Match" / "Possible Match"

---

### 5.4 Sentiment Indicators

**Visual Representation:**

| Sentiment | Icon | Color | Display |
|-----------|------|-------|---------|
| Positive | 😊 face.smiling | Green | "😊 Positive" |
| Negative | 😰 face.frowning | Orange | "😰 Negative" |
| Urgent | 🚨 exclamationmark.triangle | Red | "🚨 Urgent" |
| Neutral | 😐 face.dashed | Gray | (Hidden unless tapped) |

**Placement:**
- Conversation List: Next to timestamp for urgent/negative
- Message Thread: Badge on message bubble
- Priority Inbox: Prominent in row

**SwiftUI Component:**
```swift
struct SentimentBadge: View {
    let sentiment: Sentiment

    var body: some View {
        if sentiment.shouldDisplay {
            Label(sentiment.displayName, systemImage: sentiment.icon)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(sentiment.color.opacity(0.2))
                .foregroundColor(sentiment.color)
                .clipShape(Capsule())
        }
    }
}
```

---

### 5.5 Opportunity Score Display

**Badge on Conversation Row:**
```
[⭐ 92]  ← Gold star for 90+
[⭐ 78]  ← Blue star for 70-89
[⭐ 45]  ← Gray star for 50-69
```

**Full Breakdown Card:**
```
┌──────────────────────────────┐
│ 💼 Opportunity Analysis      │
├──────────────────────────────┤
│ Overall Score: 92/100        │
│                              │
│ ⭐⭐⭐⭐⭐ (4.6/5)            │
│                              │
│ Breakdown:                   │
│ • Monetary Value: 40/40 ⭐⭐⭐│
│ • Brand Fit: 28/30 ⭐⭐⭐     │
│ • Legitimacy: 18/20 ⭐⭐      │
│ • Urgency: 6/10 ⭐           │
│                              │
│ Key Insights:                │
│ • Budget mentioned: $5,000   │
│ • Verified brand (500K+)     │
│ • Product alignment: 95%     │
│ • Response deadline: 3 days  │
│                              │
│ [View Full Conversation ↓]  │
└──────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct OpportunityScoreCard: View {
    let score: OpportunityScore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "briefcase.fill")
                Text("Opportunity Analysis")
                Spacer()
                Text("\\(score.total)/100")
                    .font(.title2.bold())
            }

            // Star Rating
            HStack {
                ForEach(0..<5) { i in
                    Image(systemName: score.stars > i ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                Text("(\\(score.rating, specifier: "%.1f")/5)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Breakdown
            VStack(alignment: .leading, spacing: 8) {
                ScoreRow("Monetary Value", score: score.monetary, max: 40)
                ScoreRow("Brand Fit", score: score.brandFit, max: 30)
                ScoreRow("Legitimacy", score: score.legitimacy, max: 20)
                ScoreRow("Urgency", score: score.urgency, max: 10)
            }

            // Insights
            VStack(alignment: .leading, spacing: 4) {
                Text("Key Insights:")
                    .font(.subheadline.bold())
                ForEach(score.insights, id: \\.self) { insight in
                    Label(insight, systemImage: "checkmark.circle")
                        .font(.footnote)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}
```

---

### 5.6 AI Processing Indicators

**Loading States:**

1. **Analyzing Message:**
```
┌─────────────────────┐
│ ✨ Analyzing...     │
│ [Progress Spinner] │
└─────────────────────┘
```

2. **Drafting Reply:**
```
┌─────────────────────┐
│ ✨ Drafting reply...│
│ [Progress Bar]     │
└─────────────────────┘
```

3. **Scoring Opportunity:**
```
┌─────────────────────┐
│ 💼 Scoring...       │
│ [Progress Dots]    │
└─────────────────────┘
```

**SwiftUI Component:**
```swift
struct AIProcessingView: View {
    let type: AIFeatureType

    var body: some View {
        HStack {
            Image(systemName: type.icon)
            Text(type.loadingText)
            Spacer()
            ProgressView()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

## 6. Interaction Patterns

### 6.1 Swipe Actions

**Conversation List - Trailing Swipe (Right to Left):**

```
┌──────────────────────────┐
│ [Conversation Row]       │
│                [Del][Pin]│ ← Swipe left
└──────────────────────────┘
```

**Actions:**
- **Delete** (Red): Remove conversation
- **Archive** (Gray): Move to archive
- **Pin** (Blue): Pin to top

**Conversation List - Leading Swipe (Left to Right):**

```
┌──────────────────────────┐
│ [Read]                   │ ← Swipe right
│ [Conversation Row]       │
└──────────────────────────┘
```

**Actions:**
- **Mark Read/Unread** (Blue): Toggle read status

---

**Message Bubble - Swipe Actions:**

Leading Swipe (Reply):
```
│ [Reply] ← [Message Bubble] │
```

Trailing Swipe (React):
```
│ [Message Bubble] → [❤️😂👍] │
```

---

### 6.2 Long Press Menus

**Conversation Row Long Press:**
```
┌──────────────────────┐
│ Pin to Top           │
│ Mark as Read         │
│ Mute Notifications   │
│ Archive              │
│ Delete               │ ← Red
└──────────────────────┘
```

**Message Bubble Long Press:**
```
┌──────────────────────┐
│ Copy                 │
│ Reply                │
│ React                │
│ Forward              │
│ Delete               │ ← Red
└──────────────────────┘
```

**AI Draft Card Long Press:**
```
┌──────────────────────┐
│ Copy to Clipboard    │
│ Edit Before Sending  │
│ Report Issue         │
│ Dismiss              │
└──────────────────────┘
```

**SwiftUI Implementation:**
```swift
.contextMenu {
    Button(action: pin) {
        Label("Pin to Top", systemImage: "pin")
    }
    Button(action: markRead) {
        Label("Mark as Read", systemImage: "envelope.open")
    }
    Button(role: .destructive, action: delete) {
        Label("Delete", systemImage: "trash")
    }
}
```

---

### 6.3 Pull to Refresh

**Visual Feedback:**
```
     ↓
┌─────────────────┐
│ [Refresh Spinner]│
│                 │
│ Syncing...      │
│                 │
```

**Behavior:**
- Pull down on any scrollable list
- Show spinner + "Syncing..." text
- Sync with Firebase
- Dismiss when complete
- Haptic feedback on trigger

**SwiftUI:**
```swift
.refreshable {
    await viewModel.sync()
}
```

---

### 6.4 Keyboard Behavior

**Message Input Bar:**

**Default State:**
```
┌─────────────────────────────┐
│ [+] Type a message...  [↑] │
└─────────────────────────────┘
```

**Typing State:**
```
┌─────────────────────────────┐
│ [+] Hey, thanks for...  [↑]│ ← Blue send button
└─────────────────────────────┘
```

**Interactions:**
- **Tap [+]** → Show attachment menu (camera, photo library, file)
- **Tap Input Field** → Show keyboard with suggestions
- **Type Text** → Send button turns blue + enabled
- **Tap Send** → Send message, clear field, keyboard stays
- **Swipe Down on Screen** → Dismiss keyboard
- **Long Press [+]** → Quick actions (camera, location)

**Keyboard Toolbar:**
```
┌─────────────────────────────┐
│ [Bold] [Italic] [Emoji]     │ ← Above keyboard
├─────────────────────────────┤
│ [Keyboard]                  │
└─────────────────────────────┘
```

---

### 6.5 Haptic Feedback

**Haptic Events:**

| Action | Haptic Type | When |
|--------|-------------|------|
| Send Message | .success | Message sent successfully |
| Delete Conversation | .warning | Before destructive action |
| Long Press Menu | .medium | Menu appears |
| Swipe Action | .light | Action revealed |
| Pull to Refresh | .light | Refresh triggered |
| New Message | .notification | Message received |
| AI Draft Ready | .success | Draft appears |
| Error | .error | Send failed, error occurred |

**SwiftUI Implementation:**
```swift
import CoreHaptics

func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
}
```

---

## 7. Offline UI Patterns

### 7.1 Connection Status Indicator

**Status Bar (Top of Screen):**

```
┌─────────────────────────────┐
│ ⚠️ Offline - Messages queued│ ← Yellow banner
├─────────────────────────────┤
│  All Messages               │
│  ...                        │
```

**States:**
- **Online** (Default): No banner shown
- **Offline**: Yellow banner, "⚠️ Offline - Messages queued"
- **Syncing**: Blue banner, "↻ Syncing messages..."
- **Error**: Red banner, "❌ Sync failed - Tap to retry"

**SwiftUI Component:**
```swift
struct ConnectionBanner: View {
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Offline - Messages queued")
                Spacer()
                if networkMonitor.isSyncing {
                    ProgressView()
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.2))
            .foregroundColor(.orange)
        }
    }
}
```

---

### 7.2 Message Queue Indicators

**Queued Message in Conversation List:**
```
┌─────────────────────────────┐
│ [Avatar] Sarah Johnson      │
│ That's awesome! Can't...    │
│ [💬Fan] • Sending... [⏳]  │ ← Queued indicator
└─────────────────────────────┘
```

**Queued Message Bubble:**
```
  This is my reply
  [Blue Bubble]
  ⏳ Queued for sending     ← Gray text
```

**States:**
- **Queued**: ⏳ "Queued for sending"
- **Sending**: ↻ "Sending..."
- **Sent**: ✓ "Sent"
- **Failed**: ❌ "Failed to send - Tap to retry"

---

### 7.3 Offline Capabilities

**Available Actions Offline:**
- ✅ Read existing messages
- ✅ Send new messages (queued)
- ✅ View conversations
- ✅ View profile settings
- ✅ View FAQ library
- ❌ AI features (require network)
- ❌ Search (requires server)
- ❌ New conversations with unknown contacts

**Disabled Feature Indicator:**
```
┌─────────────────────────────┐
│ ✨ AI Draft Reply           │
│                             │
│ [Icon: wifi.slash]          │
│                             │
│ Requires internet connection│
│                             │
│ [OK]                        │
└─────────────────────────────┘
```

---

### 7.4 Sync Indicators

**Sync Progress (Settings):**
```
┌─────────────────────────────┐
│ Sync Status                 │
│                             │
│ Last Synced: 2 minutes ago  │
│                             │
│ [■■■■■■□□□□] 60%           │
│ Syncing 12 of 20 messages   │
│                             │
│ [Cancel Sync]               │
└─────────────────────────────┘
```

---

## 8. Accessibility Considerations

### 8.1 Dynamic Type Support

**All text scales with user preferences:**
- `.font(.body)` → Scales automatically
- `.font(.custom("SF Pro", size: 17, relativeTo: .body))` → Custom font scales
- Minimum touch target: 44x44pt (Apple HIG)
- Test at largest accessibility sizes

**Layout Adjustments:**
```swift
@Environment(\\.sizeCategory) var sizeCategory

var body: some View {
    if sizeCategory.isAccessibilityCategory {
        VStack { /* Vertical layout for large text */ }
    } else {
        HStack { /* Horizontal layout */ }
    }
}
```

---

### 8.2 VoiceOver Labels

**Critical Labels:**

| Element | VoiceOver Label |
|---------|-----------------|
| New Message Button | "Compose new message" |
| Send Button | "Send message" |
| Message Bubble (Sent) | "You sent: [message text] at [time]" |
| Message Bubble (Received) | "[Sender name] sent: [message text] at [time]" |
| Category Badge | "Categorized as [category]" |
| AI Draft Card | "AI-suggested reply: [draft text]. Double tap to edit or send." |
| Opportunity Score | "Business opportunity scored [score] out of 100" |
| Queued Message | "Message queued for sending when online" |

**Implementation:**
```swift
Button(action: sendMessage) {
    Image(systemName: "paperplane.fill")
}
.accessibilityLabel("Send message")
.accessibilityHint("Sends your message to the recipient")
```

---

### 8.3 Color Contrast

**WCAG AA Compliance:**
- Text on background: 4.5:1 minimum
- Large text (18pt+): 3:1 minimum
- Interactive elements: 3:1 minimum

**High Contrast Adjustments:**
```swift
@Environment(\\.colorScheme) var colorScheme
@Environment(\\.accessibilityHighContrast) var highContrast

var textColor: Color {
    if highContrast {
        return colorScheme == .dark ? .white : .black
    }
    return .primary
}
```

**Test with:**
- Settings → Accessibility → Display & Text Size → Increase Contrast

---

### 8.4 Reduce Motion

**Animation Adjustments:**
```swift
@Environment(\\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .spring()
}

Button("Action") { }
    .animation(animation, value: isActive)
```

**Affected Animations:**
- Message send/receive animations
- Draft card appearance
- Tab transitions
- Swipe actions

**Test with:**
- Settings → Accessibility → Motion → Reduce Motion

---

### 8.5 Keyboard Navigation

**Focus Management:**
- Tab through interactive elements
- Escape key dismisses sheets/modals
- Return key sends message (in input field)
- Arrow keys navigate lists

**iPad Support:**
- Full keyboard shortcuts
- ⌘N: New message
- ⌘R: Reply
- ⌘1-4: Switch tabs
- ⌘F: Search
- ⌘W: Close current view

---

## 9. Animation & Transitions

### 9.1 Screen Transitions

**Navigation Push/Pop:**
- Default iOS slide transition
- Duration: 0.35s
- Easing: Spring (0.7, 0.8)

**Modal Presentations:**
- Sheet: Slide up from bottom
- Full Screen: Cross-dissolve or flip horizontal
- Duration: 0.3s

**SwiftUI:**
```swift
.sheet(isPresented: $showSheet) {
    NewMessageView()
}

.fullScreenCover(isPresented: $showFullScreen) {
    OnboardingView()
}
```

---

### 9.2 List Animations

**Item Insertion:**
```swift
.transition(.asymmetric(
    insertion: .move(edge: .leading).combined(with: .opacity),
    removal: .move(edge: .trailing).combined(with: .opacity)
))
```

**Item Deletion:**
- Swipe to delete: Red background slides in
- Confirmation: Fade out + scale down
- Duration: 0.25s

**Reordering:**
- Lift effect: Scale 1.05, shadow
- Drag: Follow finger with spring
- Drop: Spring back, duration 0.35s

---

### 9.3 Message Animations

**New Message Received:**
```swift
// Message slides in from left
.transition(.move(edge: .leading).combined(with: .opacity))
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: messages)
```

**Message Sent:**
```swift
// Optimistic UI: Instantly appear
// Status updates: Fade in checkmarks
.transition(.opacity.combined(with: .scale(scale: 0.8)))
.animation(.easeOut(duration: 0.2), value: message.status)
```

**Typing Indicator:**
```swift
// Three dots bouncing in sequence
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -5 : 0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
```

---

### 9.4 AI Feature Animations

**Draft Card Appearance:**
```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(response: 0.5, dampingFraction: 0.7), value: showDraft)
```

**Category Badge Change:**
```swift
.transition(.scale.combined(with: .opacity))
.animation(.easeInOut(duration: 0.3), value: category)
```

**Opportunity Score Count-Up:**
```swift
struct CountUpText: View {
    let target: Int
    @State private var current = 0

    var body: some View {
        Text("\\(current)")
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    current = target
                }
            }
    }
}
```

---

### 9.5 Loading States

**Skeleton Loaders:**
```swift
struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}
```

**Shimmer Effect for Loading:**
- Conversation rows: Shimmer over avatar + text placeholders
- Message bubbles: Pulse opacity 0.5 → 1.0 → 0.5
- Duration: 1.5s loop

---

### 9.6 Micro-Interactions

**Button Press:**
```swift
.buttonStyle(ScaleButtonStyle())

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

**Swipe Action Reveal:**
- Spring animation with dampingFraction: 0.8
- Haptic feedback on threshold
- Color transition from transparent to action color

**Pull to Refresh:**
- Arrow rotates as user pulls
- Spinner appears at threshold
- Haptic at trigger point

---

## 10. State Specifications

### 10.1 Loading States

**Screen-Level:**
```
┌─────────────────────────────┐
│                             │
│     [Large Spinner]         │
│     Loading messages...     │
│                             │
└─────────────────────────────┘
```

**List-Level:**
```
┌─────────────────────────────┐
│ [Skeleton Row]              │
│ [Skeleton Row]              │
│ [Skeleton Row]              │
└─────────────────────────────┘
```

**Inline:**
```
│ [Avatar] Sarah Johnson      │
│ [Shimmer loading preview]   │ ← Skeleton text
│ [Shimmer] • [Shimmer]       │
```

---

### 10.2 Empty States

**No Conversations:**
```
┌─────────────────────────────┐
│                             │
│   [Icon: message.badge]     │
│                             │
│   No Messages Yet           │
│                             │
│   Start a conversation      │
│   by tapping the + button   │
│                             │
│   [Start Messaging]         │
│                             │
└─────────────────────────────┘
```

**No Priority Messages:**
```
┌─────────────────────────────┐
│                             │
│   [Icon: checkmark.circle]  │
│                             │
│   All Caught Up!            │
│                             │
│   No urgent messages        │
│   need your attention.      │
│                             │
└─────────────────────────────┘
```

**No Business Opportunities:**
```
┌─────────────────────────────┐
│                             │
│   [Icon: briefcase]         │
│                             │
│   No Opportunities Yet      │
│                             │
│   Business messages will    │
│   appear here when detected.│
│                             │
└─────────────────────────────┘
```

**No FAQs:**
```
┌─────────────────────────────┐
│                             │
│   [Icon: questionmark]      │
│                             │
│   No FAQs Added             │
│                             │
│   Add frequently asked      │
│   questions to save time.   │
│                             │
│   [Add Your First FAQ]      │
│                             │
└─────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

### 10.3 Error States

**Network Error:**
```
┌─────────────────────────────┐
│   [Icon: wifi.slash]        │
│                             │
│   Connection Lost           │
│                             │
│   Check your internet       │
│   connection and try again. │
│                             │
│   [Retry]                   │
│                             │
└─────────────────────────────┘
```

**Send Failed:**
```
│  This is my message         │
│  [Blue Bubble]              │
│  ❌ Failed to send          │
│  [Tap to retry]             │
```

**AI Error:**
```
┌─────────────────────────────┐
│ ✨ AI Draft Reply           │
│                             │
│ [Icon: exclamationmark]     │
│                             │
│ Failed to generate reply    │
│                             │
│ [Try Again] [Dismiss]       │
│                             │
└─────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Something Went Wrong")
                .font(.title2.bold())

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retry = retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

### 10.4 Success States

**Message Sent:**
```
│  This is my message         │
│  [Blue Bubble]              │
│  Sent • 2:45 PM ✓✓         │
```

**FAQ Saved:**
```
┌─────────────────────────────┐
│   [Icon: checkmark.circle]  │
│   FAQ Saved Successfully!   │
└─────────────────────────────┘
```

**AI Draft Accepted:**
```
┌─────────────────────────────┐
│   ✨ Reply Sent!            │
│   AI suggestion was used    │
└─────────────────────────────┘
```

**SwiftUI Component:**
```swift
struct SuccessToast: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

---

## 11. Platform-Specific Considerations

### 11.1 iPhone Layouts

**Safe Area Insets:**
```swift
.safeAreaInset(edge: .bottom) {
    MessageInputBar()
        .background(.ultraThinMaterial)
}
```

**Thumb Zone Optimization:**
```
┌─────────────────────────────┐
│                             │ Hard to reach
│                             │
│                             │
│         COMFORTABLE         │ Comfortable
│         THUMB ZONE          │
│                             │
├─────────────────────────────┤
│  💬    🎯    📊    👤      │ Easy reach
└─────────────────────────────┘
```

**Key Interactions in Thumb Zone:**
- Tab bar navigation
- Send button
- New message button
- Primary swipe actions

---

### 11.2 iPad Layouts

**Split View Support:**
```
┌──────────────┬──────────────────┐
│ Conversations│  Message Thread  │
│              │                  │
│ [List]       │  [Messages]      │
│              │                  │
│              │  [Input Bar]     │
└──────────────┴──────────────────┘
```

**SwiftUI Implementation:**
```swift
NavigationSplitView {
    // Sidebar: Conversation List
    ConversationListView()
} detail: {
    // Detail: Message Thread
    if let selected = selectedConversation {
        MessageThreadView(conversation: selected)
    } else {
        Text("Select a conversation")
            .foregroundColor(.secondary)
    }
}
```

**iPad-Specific Features:**
- Split view (sidebar + detail)
- Keyboard shortcuts
- Drag & drop support
- Multi-window support
- Pointer interactions

---

### 11.3 Dark Mode

**Color Adaptations:**
```swift
struct Colors {
    static let background = Color(
        light: .white,
        dark: .black
    )

    static let secondaryBackground = Color(
        light: Color(UIColor.systemGray6),
        dark: Color(UIColor.systemGray1)
    )

    static let messageBubbleSent = Color(
        light: .blue,
        dark: Color(UIColor.systemBlue)
    )

    static let messageBubbleReceived = Color(
        light: Color(UIColor.systemGray5),
        dark: Color(UIColor.systemGray2)
    )
}
```

**Dark Mode Testing Checklist:**
- [ ] All text readable on backgrounds
- [ ] Borders visible but subtle
- [ ] Shadows adjusted (lighter in dark mode)
- [ ] Icons render correctly
- [ ] AI feature cards maintain hierarchy
- [ ] Category badges remain distinguishable

---

### 11.4 Landscape Orientation

**iPhone Landscape:**
- Reduce vertical spacing
- Collapse navigation bar
- Side-by-side input bar elements

**iPad Landscape:**
- Maximize split view usage
- Show more content in lists
- Wider message bubbles (up to 60% width)

**SwiftUI Detection:**
```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass
@Environment(\.verticalSizeClass) var verticalSizeClass

var isLandscape: Bool {
    verticalSizeClass == .compact
}
```

---

## 12. Performance Considerations

### 12.1 List Performance

**Lazy Loading:**
```swift
ScrollView {
    LazyVStack {
        ForEach(messages) { message in
            MessageBubble(message)
        }
    }
}
```

**Pagination:**
- Load 50 messages initially
- Load 25 more when scrolling to top
- Show "Load More" indicator
- Cache loaded pages

**Image Loading:**
```swift
AsyncImage(url: avatarURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        Image(systemName: "person.circle.fill")
    @unknown default:
        EmptyView()
    }
}
.frame(width: 48, height: 48)
.clipShape(Circle())
```

---

### 12.2 Animation Performance

**Use `.drawingGroup()` for Complex Animations:**
```swift
VStack {
    // Complex animated content
}
.drawingGroup() // Renders off-screen, improves performance
```

**Limit Animation Frequency:**
```swift
.animation(.default, value: items.count) // Only animate on count change
// NOT: .animation(.default) // Animates everything
```

---

### 12.3 Memory Management

**Image Caching:**
- Use URLCache for network images
- Limit cache size to 100MB
- Purge cache on low memory warning

**Message Pagination:**
- Keep max 200 messages in memory
- Unload older messages when limit reached
- Reload from SwiftData when needed

---

## 13. Accessibility Quick Reference

### 13.1 VoiceOver Priority Actions

**Conversation Row:**
1. Primary: Open conversation
2. Secondary: Mark read/unread
3. Tertiary: Delete

**Message Bubble:**
1. Primary: Read message
2. Secondary: Reply
3. Tertiary: Copy

**AI Draft Card:**
1. Primary: Edit draft
2. Secondary: Send draft
3. Tertiary: Dismiss

---

### 13.2 Accessibility Testing Checklist

- [ ] All interactive elements have labels
- [ ] Complex views have accessibility containers
- [ ] Custom controls have proper traits
- [ ] Images have meaningful descriptions
- [ ] Decorative images marked as ignored
- [ ] Dynamic Type support tested (XS-XXXL)
- [ ] VoiceOver navigation logical
- [ ] Reduce Motion respected
- [ ] Color contrast meets WCAG AA
- [ ] Keyboard navigation works (iPad)

---

## 14. Localization Considerations

### 14.1 Text Expansion

**Plan for 30-40% text expansion in other languages:**
```swift
// Use flexible layouts
HStack {
    Text("Send") // Might become "Enviar" (longer in some languages)
        .layoutPriority(1)
    Spacer()
}
```

**Avoid fixed widths:**
```swift
// ❌ Bad
Text("Send").frame(width: 80)

// ✅ Good
Text("Send").padding(.horizontal)
```

---

### 14.2 RTL Support

**Right-to-Left Languages (Arabic, Hebrew):**
```swift
// SwiftUI automatically flips layouts
HStack {
    Image(systemName: "person")
    Text("Name")
    Spacer()
    Image(systemName: "chevron.right") // Auto-flips to left
}
.environment(\.layoutDirection, .rightToLeft) // For testing
```

**Test RTL Layout:**
- Settings → General → Language & Region → Add Arabic
- Xcode: Edit Scheme → Run → App Language → Arabic

---

## 15. Implementation Notes

### 15.1 SwiftUI Architecture

**MVVM Pattern:**
```
View (SwiftUI)
  ↓
ViewModel (@ObservableObject)
  ↓
Model (Sendable structs)
  ↓
Service Layer (Firebase, SwiftData)
```

**Example ViewModel:**
```swift
@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let service: MessagingService

    func loadConversations() async {
        isLoading = true
        do {
            conversations = try await service.fetchConversations()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
```

---

### 15.2 State Management

**Use @StateObject for ownership:**
```swift
struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
}
```

**Use @ObservedObject for passing:**
```swift
struct ConversationRow: View {
    @ObservedObject var conversation: Conversation
}
```

**Use @State for local UI state:**
```swift
@State private var showSheet = false
@State private var messageText = ""
```

---

### 15.3 Navigation

**iOS 17+ Navigation:**
```swift
NavigationStack(path: $navigationPath) {
    ConversationListView()
        .navigationDestination(for: Conversation.self) { conversation in
            MessageThreadView(conversation: conversation)
        }
}
```

**Deep Linking:**
```swift
.onOpenURL { url in
    if url.scheme == "sorted",
       url.host == "conversation",
       let id = url.pathComponents.last {
        navigationPath.append(Conversation(id: id))
    }
}
```

---

### 15.4 File Organization

```
Sorted/
├── App/
│   ├── SortedApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Models/
│   │   ├── Message.swift
│   │   ├── Conversation.swift
│   │   └── User.swift
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── SwiftDataService.swift
│   │   └── AIService.swift
│   └── Utilities/
│       ├── NetworkMonitor.swift
│       └── Extensions.swift
├── Features/
│   ├── Conversations/
│   │   ├── Views/
│   │   │   ├── ConversationListView.swift
│   │   │   └── ConversationRow.swift
│   │   └── ViewModels/
│   │       └── ConversationListViewModel.swift
│   ├── Messages/
│   │   ├── Views/
│   │   │   ├── MessageThreadView.swift
│   │   │   └── MessageBubble.swift
│   │   └── ViewModels/
│   │       └── MessageThreadViewModel.swift
│   ├── AI/
│   │   ├── Views/
│   │   │   ├── DraftReplyCard.swift
│   │   │   ├── CategoryBadge.swift
│   │   │   └── OpportunityScoreCard.swift
│   │   └── ViewModels/
│   │       └── AIFeaturesViewModel.swift
│   ├── Profile/
│   │   ├── Views/
│   │   │   ├── ProfileView.swift
│   │   │   └── FAQLibraryView.swift
│   │   └── ViewModels/
│   │       └── ProfileViewModel.swift
│   └── Onboarding/
│       └── Views/
│           ├── WelcomeView.swift
│           └── OnboardingCarousel.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

---

## 16. Design Handoff Checklist

### 16.1 For Developers

- [x] All screen specifications documented
- [x] Component library defined
- [x] Color palette with semantic naming
- [x] Typography scale specified
- [x] Spacing system (8pt grid)
- [x] Icon library (SF Symbols)
- [x] Animation specifications
- [x] State specifications (loading, error, empty)
- [x] Interaction patterns documented
- [x] Accessibility requirements listed
- [x] SwiftUI component examples provided

### 16.2 Design Assets Needed

**From Designer:**
- [ ] App icon (1024x1024px)
- [ ] Launch screen assets
- [ ] Onboarding illustrations (optional, can use SF Symbols)
- [ ] Empty state illustrations (optional)
- [ ] Custom icons (if not using SF Symbols)

**Developer-Generated:**
- [ ] All UI implemented in SwiftUI (no static images)
- [ ] Dynamic colors for light/dark mode
- [ ] SF Symbols for all icons
- [ ] Native iOS components

---

## 17. Testing Scenarios

### 17.1 User Flow Testing

**Critical Path Tests:**
1. **Onboarding → First Message**
   - Launch app → Complete onboarding → Send first message

2. **Message Triage**
   - Open app → Scan conversation list → Open priority message → Respond

3. **AI Draft Usage**
   - Receive message → View AI draft → Edit → Send

4. **Business Opportunity**
   - Check Business tab → Review high-scoring opportunity → Respond

5. **FAQ Setup & Use**
   - Add FAQ → Receive matching question → Use suggested answer

---

### 17.2 Edge Cases

**Test Scenarios:**
- [ ] Very long message (1000+ characters)
- [ ] Rapid-fire messages (20+ in 10 seconds)
- [ ] Poor network (throttled connection)
- [ ] Offline mode (airplane mode)
- [ ] Low storage space
- [ ] Low battery mode
- [ ] Interrupted by phone call
- [ ] App backgrounded during send
- [ ] Force quit during sync
- [ ] Large images (10MB+)
- [ ] Group chat with 10+ participants
- [ ] Empty conversation list
- [ ] All messages marked as spam
- [ ] No business opportunities

---

### 17.3 Accessibility Testing

**Test with Settings:**
- [ ] Dynamic Type (XS through XXXL)
- [ ] Bold Text
- [ ] Increase Contrast
- [ ] Reduce Transparency
- [ ] Reduce Motion
- [ ] VoiceOver enabled
- [ ] Voice Control enabled
- [ ] Switch Control

---

## 18. Success Metrics (UX)

### 18.1 Usability Metrics

**Target Metrics:**
- Time to first message: < 60 seconds (new users)
- Time to triage 10 messages: < 2 minutes
- AI draft acceptance rate: > 60%
- FAQ match accuracy (user satisfaction): > 85%
- App crash rate: < 0.1%
- Task completion rate: > 95%

---

### 18.2 User Feedback

**In-App Feedback Collection:**
- Thumbs up/down on AI suggestions
- "Report Issue" on AI drafts
- NPS survey after 7 days
- Feature request form in settings

**Analytics Events:**
```swift
// Track key interactions
Analytics.logEvent("ai_draft_accepted", parameters: nil)
Analytics.logEvent("ai_draft_edited", parameters: ["edit_type": "minor"])
Analytics.logEvent("faq_used", parameters: ["category": "equipment"])
Analytics.logEvent("opportunity_responded", parameters: ["score": 92])
```

---

## 19. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Oct 20, 2025 | UX Expert | Initial comprehensive UX/UI specifications |

---

## 20. References

### 20.1 Design Resources

- **Apple Human Interface Guidelines:** https://developer.apple.com/design/human-interface-guidelines/
- **SF Symbols:** https://developer.apple.com/sf-symbols/
- **iOS 17 Design Kit:** Apple Design Resources
- **SwiftUI Documentation:** https://developer.apple.com/documentation/swiftui/

### 20.2 Development Resources

- **SwiftUI Tutorials:** https://developer.apple.com/tutorials/swiftui
- **Firebase iOS SDK:** https://firebase.google.com/docs/ios/setup
- **Accessibility:** https://developer.apple.com/accessibility/
- **TestFlight:** https://developer.apple.com/testflight/

---

**END OF UX/UI SPECIFICATIONS**

*These specifications are designed for iOS 17+ SwiftUI development with native design patterns, AI-first features, and offline-first architecture. All designs prioritize content creator workflows and one-handed mobile usage.*