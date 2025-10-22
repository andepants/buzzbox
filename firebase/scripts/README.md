# Firebase Scripts

This directory contains Firebase administrative scripts for BuzzBox.

## Channel Seeding

### Prerequisites

1. **Install Firebase Admin SDK:**
   ```bash
   npm install firebase-admin
   ```

2. **Download Service Account Key:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file securely (DO NOT commit to git)

3. **Set Environment Variable:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   ```

### Seeding Default Channels

Run this script **ONCE** before app launch to create the default channels:

```bash
cd firebase/scripts
node seed-channels.js
```

This creates 3 channels:
- **#general** - Main discussion (everyone can post)
- **#announcements** - Creator posts only (read-only for fans)
- **#off-topic** - Casual chat (everyone can post)

### Verification

After seeding:
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Navigate to Firestore Database
3. Check the `conversations` collection
4. Verify 3 documents exist: `general`, `announcements`, `off-topic`
5. Verify `isCreatorOnly: true` for `announcements`

### Auto-Join

New users automatically join all channels on signup (see AuthService.createUser).

## Security

**⚠️ IMPORTANT:**
- Never commit service account keys to git
- Add `*-key.json` to `.gitignore`
- Rotate keys regularly
- Use different keys for dev/staging/production
