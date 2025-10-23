# Push Notifications on iOS Simulator

## Summary

iOS Simulators have **limited push notification support**. This implementation provides multiple notification approaches optimized for simulator testing and production use.

## What Was Implemented

### 1. NotificationService (NEW)
- **Location:** `buzzbox/Core/Services/NotificationService.swift`
- **Features:**
  - In-app banner notifications (works perfectly on simulator)
  - Local notification scheduling (works on simulator)
  - Automatic duplicate prevention (won't notify if viewing conversation)
  - Auto-dismiss after 5 seconds

### 2. Integration Points

#### MessageThreadViewModel
- Triggers notifications when new messages arrive from other users
- Fetches sender display name from Firestore
- Calls both in-app and local notification methods

#### RootView
- Added `.notificationBanner()` modifier to show in-app banners
- Deep linking from notifications already implemented

#### MessageThreadView
- Tracks when user is viewing a conversation
- Prevents duplicate notifications for active conversation
- Clears badge when viewing messages

## How It Works

### When a message arrives:

1. **MessageThreadViewModel** receives message via Firebase Realtime Database
2. If message is from another user, it triggers `triggerNotificationForMessage()`
3. **NotificationService** checks if user is viewing that conversation
4. If not viewing, it shows:
   - **In-app banner** at top of screen (animated slide-in)
   - **Local notification** (appears in Notification Center on simulator)

### User Experience:

- **User in different conversation:** Banner slides in from top
- **User taps banner:** Opens that conversation via deep link
- **User dismisses banner:** Taps X button or auto-dismisses after 5s
- **User already viewing conversation:** No duplicate notification shown

## Simulator Limitations

| Feature | Simulator Support | Our Solution |
|---------|------------------|--------------|
| Remote push (APNs) | ❌ No | ✅ In-app banner + local notification |
| Foreground notifications | ✅ Yes | ✅ Already working (AppDelegate line 135) |
| Background delivery | ⚠️ Limited | ✅ Local notifications work |
| Notification sounds | ⚠️ Limited | ✅ Enabled in local notifications |
| Badges | ✅ Yes | ✅ Badge count implemented |

## Testing on Simulator

### Test In-App Notifications:
1. Open app with two users (user A and user B)
2. Login as user A on one simulator
3. Login as user B on another simulator
4. User B sends message to user A
5. User A should see:
   - In-app banner slide from top
   - Message content and sender name
   - Tappable to open conversation

### Test Local Notifications:
1. Follow steps 1-4 above
2. Swipe down from top of simulator screen
3. Should see notification in Notification Center
4. Tap notification → app opens to conversation

## Testing on Physical Device

On physical devices, you get the full experience:
- Remote push notifications work via APNs
- Background delivery works
- Cloud Functions trigger push notifications
- Lock screen notifications work

## Simulator Push via simctl (Advanced)

For iOS 16.4+, you can simulate push notifications:

```bash
# 1. Get simulator UDID
xcrun simctl list devices | grep Booted

# 2. Create notification payload JSON
cat > notification.json <<EOF
{
  "Simulator Target Bundle": "com.theheimlife.buzzbox",
  "aps": {
    "alert": {
      "title": "Andrew Heim Dev",
      "body": "Hey! How's it going?"
    },
    "badge": 1,
    "sound": "default"
  },
  "conversationID": "your-conversation-id"
}
EOF

# 3. Send notification
xcrun simctl push <UDID> com.theheimlife.buzzbox notification.json
```

## Architecture Benefits

✅ **Simulator-friendly:** In-app notifications work perfectly on simulator
✅ **Device-ready:** Seamlessly transitions to remote push on device
✅ **No duplicates:** Smart tracking prevents notification spam
✅ **Deep linking:** Tapping notifications opens correct conversation
✅ **User-aware:** Respects user context (no notif if already viewing)

## Files Modified

1. ✅ `buzzbox/Core/Services/NotificationService.swift` (NEW)
2. ✅ `buzzbox/Features/Chat/ViewModels/MessageThreadViewModel.swift`
   - Added `triggerNotificationForMessage()`
   - Added `fetchSenderName()`
3. ✅ `buzzbox/App/Views/RootView.swift`
   - Added `.notificationBanner()` modifier
4. ✅ `buzzbox/Features/Chat/Views/MessageThreadView.swift`
   - Added conversation tracking on appear/disappear

## Next Steps (Optional)

- [ ] Add notification sounds (custom audio files)
- [ ] Implement notification action buttons (reply, mark as read)
- [ ] Add notification grouping for multiple messages
- [ ] Implement notification settings (mute conversations)
- [ ] Add rich notifications with images

## Troubleshooting

**No notifications appearing?**
1. Check notification permissions: Settings → Buzzbox → Notifications
2. Verify Firebase Realtime Database is connected
3. Check console logs for `✅ Local notification scheduled`
4. Ensure you're testing with different users

**Banner not showing?**
1. Check that `.notificationBanner()` is added to RootView
2. Verify NotificationService singleton is initialized
3. Check that conversation IDs match

**Notifications showing when viewing conversation?**
1. Verify `setCurrentConversation()` is called in `.task`
2. Check that conversation ID is correct
3. Ensure `onDisappear` clears the tracking
