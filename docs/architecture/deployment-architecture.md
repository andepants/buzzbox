# Deployment Architecture

### 9.1 Environment Strategy

**Three Environments:**

| Environment | Purpose | Firebase Project | TestFlight | Users |
|-------------|---------|------------------|------------|-------|
| **Development** | Local dev | sorted-dev | No | Developers |
| **Staging** | Internal testing | sorted-staging | Internal | Team |
| **Production** | Live app | sorted-prod | External → App Store | End users |

**Development:**
- Firebase emulators for Auth, Firestore, Functions
- Mock AI responses (no actual OpenAI calls)
- Hot reload, fast iteration

**Staging:**
- Real Firebase backend (staging project)
- Real AI with rate limits (50 req/user/hour)
- Internal TestFlight distribution
- Team testing, bug fixes

**Production:**
- Production Firebase project
- Full AI access (100 req/user/hour)
- External TestFlight → App Store
- Real users

### 9.2 Build Configurations

**Xcode Schemes:**
- Sorted-Dev (Debug build, emulators)
- Sorted-Staging (Release build, staging Firebase)
- Sorted-Production (Release build, production Firebase)

**Bundle IDs:**
- Development: `com.sorted.app.dev`
- Staging: `com.sorted.app.staging`
- Production: `com.sorted.app`

### 9.3 TestFlight Distribution

**Day 7 Deployment:**
1. Archive build in Xcode
2. Upload to App Store Connect
3. Add to TestFlight (Internal Testing first)
4. Write release notes
5. Add testers (up to 100 internal, 10,000 external)
6. Submit for Beta App Review (external testing)

**TestFlight Groups:**
- Internal: Team members, immediate access
- External: Beta testers, requires Beta App Review (~24-48 hours)

### 9.4 Cloud Functions Deployment

Deploy via Firebase CLI:
```bash
firebase deploy --only functions --project sorted-prod
```

Set environment variables:
```bash
firebase functions:config:set openai.api_key="sk-..." --project sorted-prod
```
