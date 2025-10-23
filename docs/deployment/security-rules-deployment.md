# Firebase Security Rules Deployment Guide

## Overview
This guide provides instructions for deploying and testing Firebase Security Rules for Firestore and Realtime Database.

**Last Updated:** 2025-10-22
**Story:** 5.7 - Firebase Security Rules Deployment

## Security Rules Summary

### Firestore Rules (`firestore.rules`)
1. **User Type-Based Access Control**
   - All authenticated users can read user profiles
   - Only owner can update their own profile
   - `userType` and `isPublic` are immutable after creation

2. **Creator Profile Publicly Readable**
   - Creator profile (`isPublic = true`) is readable by all authenticated users

3. **Fan Profile Discovery**
   - Fans can read other fan profiles for channel participant context

4. **Conversation Permissions**
   - Only conversation participants can read/write conversations
   - Creator or participants can delete conversations

5. **DM Restrictions** (Story 5.4)
   - Fans can only DM with creator
   - Creator can DM with anyone
   - Both fans cannot DM each other

### Realtime Database Rules (`database.rules.json`)
1. **Message Permissions**
   - Only conversation participants can read messages
   - Only sender can write their own messages

2. **Creator-Only Channel Restrictions** (Story 5.7)
   - If `isCreatorOnly = true`, only creator can post messages
   - Regular channels allow all participants to post

3. **Typing Indicators**
   - All participants can read typing indicators
   - Users can only write their own typing status

4. **User Presence**
   - All authenticated users can read presence status
   - Users can only update their own presence

## Testing Rules in Firebase Console

### Firestore Rules Testing

1. **Navigate to Rules Playground:**
   - Go to Firebase Console → Firestore Database → Rules
   - Click "Rules Playground" tab

2. **Test Case 1: Fan-to-Fan DM Creation (Should FAIL)**
   ```
   Operation: Create
   Location: /databases/(default)/documents/conversations/fan1_fan2
   Authenticated: Yes
   User ID: fan1_uid
   Request Data:
   {
     "participantIDs": ["fan1_uid", "fan2_uid"],
     "isGroup": false
   }
   Expected: DENY (DM restriction enforced)
   ```

3. **Test Case 2: Fan-to-Creator DM (Should SUCCEED)**
   ```
   Operation: Create
   Location: /databases/(default)/documents/conversations/fan1_creator
   Authenticated: Yes
   User ID: fan1_uid
   Request Data:
   {
     "participantIDs": ["fan1_uid", "creator_uid"],
     "isGroup": false
   }
   Expected: ALLOW
   ```

4. **Test Case 3: User Profile Read (Should SUCCEED)**
   ```
   Operation: Get
   Location: /databases/(default)/documents/users/creator_uid
   Authenticated: Yes
   User ID: fan1_uid
   Expected: ALLOW (all authenticated users can read profiles)
   ```

### Realtime Database Rules Testing

1. **Navigate to Rules Simulator:**
   - Go to Firebase Console → Realtime Database → Rules
   - Use Firebase CLI for testing (recommended)

2. **Test Case 1: Fan Posting to #general (Should SUCCEED)**
   ```bash
   firebase database:get /conversations/general_channel_id/isCreatorOnly
   # Returns: false

   # Simulate write as fan
   firebase database:profile /messages/general_channel_id/message123 \
     --auth fan1_uid --write '{
       "senderId": "fan1_uid",
       "text": "Hello everyone!"
     }'
   Expected: ALLOW
   ```

3. **Test Case 2: Fan Posting to #announcements (Should FAIL)**
   ```bash
   firebase database:get /conversations/announcements_channel_id/isCreatorOnly
   # Returns: true

   # Simulate write as fan
   firebase database:profile /messages/announcements_channel_id/message123 \
     --auth fan1_uid --write '{
       "senderId": "fan1_uid",
       "text": "Announcement!"
     }'
   Expected: DENY (creator-only channel)
   ```

4. **Test Case 3: Creator Posting to #announcements (Should SUCCEED)**
   ```bash
   # Simulate write as creator
   firebase database:profile /messages/announcements_channel_id/message123 \
     --auth creator_uid --write '{
       "senderId": "creator_uid",
       "text": "Official announcement!"
     }'
   Expected: ALLOW
   ```

## Deployment Steps

### Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in to Firebase: `firebase login`
- Proper project access (Editor or Owner role)

### Deployment Commands

#### Option 1: Deploy All Rules
```bash
# From project root
firebase deploy --only firestore:rules,database
```

#### Option 2: Deploy Individually
```bash
# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Realtime Database rules only
firebase deploy --only database
```

### Verification After Deployment

1. **Check deployment status:**
   ```bash
   firebase firestore:rules:get
   firebase database:rules:get
   ```

2. **Monitor Firebase Console:**
   - Check for any rule violation errors
   - Review recent rule execution metrics

3. **Test in production:**
   - Test fan signup and channel auto-join
   - Test fan can view Andrew's profile
   - Test fan can DM Andrew
   - Test fan cannot DM another fan
   - Test fan can post to #general
   - Test fan cannot post to #announcements

## Rollback Procedure

### Backup Current Rules
```bash
# Backup Firestore rules
firebase firestore:rules:get > firestore.rules.backup

# Backup RTDB rules
firebase database:rules:get > database.rules.backup
```

### Restore from Backup
```bash
# Restore Firestore rules
firebase deploy --only firestore:rules --file=firestore.rules.backup

# Restore RTDB rules
firebase deploy --only database --file=database.rules.backup
```

### Manual Rollback via Console
1. Open Firebase Console
2. Navigate to Firestore → Rules → Release History
3. Click on previous version
4. Click "Restore"
5. Repeat for Realtime Database

## Monitoring and Alerts

### Monitor Rule Violations
1. **Firebase Console:**
   - Firestore → Usage → Rules evaluation
   - Realtime Database → Usage → Operations

2. **Cloud Logging:**
   - Filter for `firestore.googleapis.com/security_rule_evaluation`
   - Look for denied operations

### Set Up Alerts
1. Create alert for high rate of denied operations
2. Create alert for unexpected rule changes
3. Monitor for failed deployments

## Troubleshooting

### Common Issues

1. **Rules deployment fails:**
   - Check syntax errors in rules files
   - Verify Firebase CLI is up to date
   - Check project permissions

2. **Unexpected denials:**
   - Check user authentication status
   - Verify user `userType` is set correctly
   - Check conversation `participantIDs` array
   - Verify `isCreatorOnly` flag on channels

3. **Performance issues:**
   - Check for excessive `get()` calls in rules
   - Consider caching user data in client
   - Optimize rule evaluation logic

## Security Best Practices

1. **Principle of Least Privilege:**
   - Only grant minimum required permissions
   - Use explicit allow rules, default deny

2. **Validate All Input:**
   - Check data types and structure
   - Validate required fields
   - Ensure immutable fields don't change

3. **Regular Audits:**
   - Review rules quarterly
   - Check for unused rules
   - Update based on new features

4. **Testing:**
   - Test all rule changes before deployment
   - Use Rules Playground for validation
   - Test with both creator and fan accounts

## References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Realtime Database Security Rules](https://firebase.google.com/docs/database/security)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-22 | 1.0 | Initial deployment guide for Story 5.7 | Dev Agent |
