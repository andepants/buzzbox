# Offline-First Strategy

### 7.1 Offline Architecture

**Core Principle:** App works seamlessly without network. Users never see errors or blocked actions.

**Write Operations:**
1. User action → Write to SwiftData immediately
2. Display change instantly (optimistic UI)
3. Queue for background sync
4. Sync when network available
5. Update UI with final status

**Read Operations:**
1. Read from SwiftData first (instant)
2. Fetch from Firestore in background if online
3. Update SwiftData cache
4. UI updates automatically via SwiftData observation

**Network Monitoring:**
- Continuously monitor network status with `NWPathMonitor`
- Display offline banner when disconnected
- Trigger sync queue processing when connection restored

**Sync Queue:**
- All pending operations stored in SwiftData with `syncStatus: .pending`
- BackgroundSyncService processes queue when online
- Exponential backoff for failed sync attempts
- Max 3 retries before marking as failed

**Conflict Resolution:**
- Last-write-wins based on Firestore server timestamp
- Local changes always take precedence until synced
- If sync fails after 3 attempts, show user error with retry option

### 7.2 Offline UI Indicators

- **Message Status:** Sending (clock) → Sent (single check) → Delivered (double check)
- **Offline Banner:** "Offline - Messages will sync when connected"
- **Failed Messages:** Red exclamation mark, tap to retry
- **Sync Queue:** Badge showing number of pending messages
