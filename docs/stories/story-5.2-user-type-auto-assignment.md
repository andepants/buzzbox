# Story 5.2: User Type Auto-Assignment

## Status
Draft

## Story
**As the** system,
**I want** to automatically assign user types based on email,
**so that** Andrew is the creator and everyone else is a fan without manual selection.

## Acceptance Criteria

1. Andrew's account (andrewsheim@gmail.com) has `userType = .creator`
2. All other accounts have `userType = .fan`
3. No onboarding user type selection screen exists
4. User type assignment happens automatically during account creation
5. Creator has `isPublic = true`, fans have `isPublic = false`
6. User type is persisted to both SwiftData and Firestore
7. User type cannot be changed after account creation (immutable)

## Tasks / Subtasks

- [ ] Add UserType enum and properties to data models (AC: 1, 2, 5, 6)
  - [ ] Define UserType enum with .creator and .fan cases
  - [ ] Add userType property to UserEntity (@Model)
  - [ ] Add isPublic property to UserEntity
  - [ ] Make both properties Codable for Firestore sync
  - [ ] Add to Firestore user document schema

- [ ] Implement auto-assignment logic (AC: 1, 2, 4, 5)
  - [ ] Create assignUserType() helper function in AuthService
  - [ ] Check if email matches CREATOR_EMAIL constant
  - [ ] Return .creator for match, .fan for non-match
  - [ ] Set isPublic based on userType
  - [ ] Call during user creation in signup flow

- [ ] Remove user type selection UI (AC: 3)
  - [ ] Remove any onboarding screens that ask for user type
  - [ ] Simplify onboarding to: email → username → done
  - [ ] Remove user type selection from profile settings
  - [ ] Clean up related ViewModels and state management

- [ ] Enforce immutability (AC: 7)
  - [ ] Ensure userType cannot be edited in profile
  - [ ] Remove any UI that allows changing userType
  - [ ] Add validation in Firestore security rules
  - [ ] Prevent userType changes in AuthService

- [ ] Update Firebase security rules (AC: 6)
  - [ ] Add userType field validation in Firestore rules
  - [ ] Ensure only valid values (.creator or .fan) can be written
  - [ ] Prevent users from changing their own userType
  - [ ] Allow reading userType for authorization checks

- [ ] Add creator identification throughout app (AC: 1)
  - [ ] Add isCreator computed property to UserEntity
  - [ ] Use for conditional UI/features
  - [ ] Display creator badge on Andrew's profile
  - [ ] Enable creator-specific features

## Dev Notes

### Architecture Context

**Data Model Changes:**
```swift
@Model
final class UserEntity {
    var id: String
    var email: String
    var displayName: String
    var photoURL: String?

    // NEW: User type properties
    var userType: UserType
    var isPublic: Bool

    // Computed property for convenience
    var isCreator: Bool {
        userType == .creator
    }
}

enum UserType: String, Codable {
    case creator
    case fan
}
```

**Constants:**
```swift
// Define in a Constants.swift file
struct AppConstants {
    static let CREATOR_EMAIL = "andrewsheim@gmail.com"
}
```

**Auto-Assignment Logic:**
```swift
// In AuthService
func assignUserType(for email: String) -> (userType: UserType, isPublic: Bool) {
    if email == AppConstants.CREATOR_EMAIL {
        return (.creator, true)
    } else {
        return (.fan, false)
    }
}
```

**Integration Point:**
```swift
// During user creation in AuthService.signUp()
let (userType, isPublic) = assignUserType(for: email)
let user = UserEntity(
    id: firebaseUser.uid,
    email: email,
    userType: userType,
    isPublic: isPublic
    // ... other properties
)
```

### Source Tree
```
Core/
├── Models/
│   ├── UserEntity.swift (Add userType, isPublic)
│   └── UserType.swift (NEW enum)
├── Services/
│   └── AuthService.swift (Add assignUserType method)
└── Utilities/
    └── Constants.swift (Add CREATOR_EMAIL)
```

### Firebase Schema Update

**Firestore User Document:**
```javascript
/users/{userId} {
  id: string,
  email: string,
  displayName: string,
  photoURL: string?,
  userType: "creator" | "fan",  // NEW
  isPublic: boolean,             // NEW
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Dependencies
- **Depends on:** Story 5.1 (Email Authentication) - User model changes
- **Blocks:** Story 5.4 (DM Restrictions), Story 5.5 (Creator Inbox) - Need userType for permissions

## Testing

### Testing Standards
- Manual testing for user creation flows
- Test on physical device with Firebase
- Verify Firestore documents have correct structure
- Check Firebase console for data validation

### Test Cases

1. **Creator Account Creation:**
   - Sign up with andrewsheim@gmail.com
   - Verify userType = "creator" in Firestore
   - Verify isPublic = true
   - Verify isCreator computed property returns true
   - Check SwiftData cache matches Firestore

2. **Fan Account Creation:**
   - Sign up with any other email
   - Verify userType = "fan" in Firestore
   - Verify isPublic = false
   - Verify isCreator computed property returns false
   - Check SwiftData cache matches Firestore

3. **Immutability:**
   - Attempt to change userType via app UI (should be impossible)
   - Attempt to change userType via Firestore console (should be rejected by rules)
   - Verify no UI exists for changing userType

4. **Onboarding Simplification:**
   - Complete signup flow
   - Verify no user type selection screen appears
   - Verify flow is: email → password → username → channels

5. **Security Rules:**
   - Test Firestore rules prevent invalid userType values
   - Test users cannot modify their own userType
   - Test userType is readable for authorization

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
