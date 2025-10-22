# Story 5.1: Email Authentication

## Status
Draft

## Story
**As a** new user,
**I want** to create an account with email and password,
**so that** I can join Andrew's community and start chatting.

## Acceptance Criteria

1. User can sign up with email/password
2. User can login with email/password
3. No email verification required (production-first approach)
4. Andrew's email (andrewsheim@gmail.com) automatically gets creator privileges
5. Dev login button works in debug builds for quick testing
6. Phone authentication code is completely removed
7. Firebase Email/Password authentication is properly configured
8. User type is automatically assigned based on email on account creation
9. Error handling provides clear, actionable feedback for common scenarios
10. Password requirements are clearly communicated (6+ characters minimum, Firebase default)

## Tasks / Subtasks

- [ ] Remove phone authentication infrastructure (AC: 6)
  - [ ] Remove phone auth UI screens (PhoneAuthView, VerificationCodeView)
  - [ ] Remove phone auth methods from AuthService
  - [ ] Clean up phone-related user model properties if any
  - [ ] Update Firebase configuration to disable phone auth

- [ ] Implement Firebase Email/Password authentication (AC: 1, 2, 3, 7)
  - [ ] Add email/password sign up method to AuthService
  - [ ] Add email/password login method to AuthService
  - [ ] Ensure no email verification is required (disable in Firebase)
  - [ ] Handle Firebase Auth errors appropriately
  - [ ] Update AuthViewModel to use new email auth methods

- [ ] Create email authentication UI (AC: 1, 2, 9, 10)
  - [ ] Create EmailSignUpView with email/password fields
  - [ ] Create EmailLoginView with email/password fields
  - [ ] Add form validation (valid email format, password min 6 chars)
  - [ ] Display password requirements below password field
  - [ ] Show real-time validation feedback
  - [ ] Display appropriate error messages for Firebase errors
  - [ ] Add loading states during authentication

- [ ] Implement comprehensive error handling (AC: 9, 10)
  - [ ] Handle "email already in use" → Show "Try logging in instead"
  - [ ] Handle "weak password" → Show password requirements (6+ chars)
  - [ ] Handle "invalid email" → Show valid email format hint
  - [ ] Handle "wrong password" → Show "Incorrect password" error
  - [ ] Handle "user not found" → Show "Account not found" error
  - [ ] Handle network errors → Show retry button
  - [ ] Handle generic Firebase errors → Show "Something went wrong"

- [ ] Implement creator identification logic (AC: 4, 8)
  - [ ] Define CREATOR_EMAIL constant ("andrewsheim@gmail.com")
  - [ ] Check user email during signup/login
  - [ ] Auto-assign userType = .creator if email matches
  - [ ] Auto-assign userType = .fan for all other emails
  - [ ] Set isPublic = true for creator, false for fans

- [ ] Add dev login button (AC: 5)
  - [ ] Create dev login button in login screen
  - [ ] Use #if DEBUG conditional compilation
  - [ ] Auto-fill andrewsheim@gmail.com / test1234
  - [ ] Trigger automatic login on button tap
  - [ ] Ensure button is hidden in release builds

- [ ] Update user model (AC: 8)
  - [ ] Add UserType enum (.creator, .fan)
  - [ ] Add userType property to UserEntity
  - [ ] Add isPublic property to UserEntity
  - [ ] Update Firestore schema to include new fields
  - [ ] Ensure SwiftData model migrations handle new properties

## Dev Notes

### Architecture Context

**Authentication Layer:**
- Use Firebase Auth for email/password authentication
- AuthService should be protocol-based (AuthServiceProtocol)
- AuthViewModel is @MainActor and manages UI state
- Follow async/await pattern for all auth operations

**Data Models:**
- UserEntity is a SwiftData @Model class
- Must be Codable for Firestore sync
- New properties: `userType: UserType`, `isPublic: Bool`
- Update both SwiftData schema and Firestore schema

**MVVM Pattern:**
- Views: Pure SwiftUI, no business logic
- ViewModels: @MainActor, ObservableObject, @Published properties
- Services: Protocol-based, async/await
- Never access services directly from views

**Firebase Strategy:**
- Use Firebase Auth for authentication
- Store user profiles in Firestore (static data)
- SwiftData for local caching and offline access

**Migration Strategy:**
- This is a greenfield implementation (no existing users)
- No migration from phone auth required
- Fresh start with email-only authentication

### Source Tree
```
Core/
├── Models/
│   └── UserEntity.swift (Add userType, isPublic)
├── Views/
│   └── Auth/
│       ├── EmailSignUpView.swift (NEW)
│       └── EmailLoginView.swift (NEW)
├── ViewModels/
│   └── AuthViewModel.swift (Update for email auth)
└── Services/
    └── AuthService.swift (Remove phone, add email methods)
```

### Implementation Notes

**Creator Email Constant:**
```swift
let CREATOR_EMAIL = "andrewsheim@gmail.com"
```

**UserType Enum:**
```swift
enum UserType: String, Codable {
    case creator
    case fan
}
```

**Auto-Assignment Logic:**
```swift
if user.email == CREATOR_EMAIL {
    user.userType = .creator
    user.isPublic = true
} else {
    user.userType = .fan
    user.isPublic = false
}
```

## Testing

### Testing Standards
- Manual testing required for authentication flows
- Test both debug and release builds to verify dev button visibility
- Test on physical device for Firebase Auth integration
- Verify Firebase console shows new users with correct properties

### Test Cases
1. **Sign Up Flow:**
   - Enter valid email/password → account created successfully
   - Enter invalid email → show validation error
   - Enter short password → show validation error
   - Sign up with andrewsheim@gmail.com → verify userType = creator
   - Sign up with other email → verify userType = fan

2. **Login Flow:**
   - Login with valid credentials → success
   - Login with wrong password → show error
   - Login with non-existent email → show error
   - Login as creator → verify creator privileges

3. **Dev Login (Debug Only):**
   - Dev button visible in debug builds
   - Dev button hidden in release builds
   - Dev button auto-fills and logs in as Andrew

4. **Data Persistence:**
   - User data saved to Firestore with new fields
   - SwiftData cache updated correctly
   - Offline mode works (can view profile when offline)

5. **Phone Auth Removal:**
   - No phone auth UI visible
   - No phone auth methods callable
   - App builds without phone auth dependencies

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
