# QA Test: Firebase Storage Image Upload & Display Workflow

**Epic:** Epic 1 - User Authentication & Profiles
**Story:** Story 1.5 - Profile Picture Management
**Date:** October 20, 2025
**Reviewer:** Sarah (@po - Product Owner)

---

## Test Objective

Verify that images uploaded to Firebase Storage are correctly:
1. Uploaded with proper compression and metadata
2. Return valid HTTPS download URLs (not gs:// reference URLs)
3. Display correctly using Kingfisher library
4. Show proper loading states with ActivityIndicatorView
5. Handle errors gracefully

---

## Firebase Storage URL Format Analysis

### ✅ CORRECT: HTTPS Download URL
```
https://firebasestorage.googleapis.com/v0/b/sorted-d3844.appspot.com/o/profile_pictures%2F{userId}%2Fprofile.jpg?alt=media&token=abc123...
```

**Properties:**
- **Scheme:** `https://` (required for Kingfisher & AsyncImage)
- **Host:** `firebasestorage.googleapis.com`
- **Path:** Encoded storage path with `%2F` for slashes
- **Query Params:**
  - `alt=media` - Returns file content
  - `token=...` - Security token for public access

**Works with:**
- ✅ Kingfisher `KFImage(url)`
- ✅ SwiftUI `AsyncImage(url:)`
- ✅ URLSession direct downloads
- ✅ Standard `<img>` tags in web

---

### ❌ INCORRECT: gs:// Reference URL
```
gs://sorted-d3844.appspot.com/profile_pictures/{userId}/profile.jpg
```

**Properties:**
- **Scheme:** `gs://` (Firebase Storage reference protocol)
- **Cannot be used directly** for image display
- **Requires Firebase SDK** to resolve to HTTPS URL

**Does NOT work with:**
- ❌ Kingfisher (expects HTTP/HTTPS)
- ❌ AsyncImage (expects HTTP/HTTPS)
- ❌ Standard image loaders

---

## Implementation Verification Checklist

### ✅ StorageService Implementation

```swift
// ✅ CORRECT: Returns HTTPS download URL
let downloadURL = try await storageRef.downloadURL()
guard downloadURL.scheme == "https" else {
    throw StorageError.invalidDownloadURL
}
return downloadURL

// ❌ WRONG: Don't return StorageReference
// return storageRef // This is gs://, not usable!
```

**Verification Steps:**
1. Upload test image
2. Inspect returned URL
3. Verify URL scheme is "https"
4. Verify URL contains `firebasestorage.googleapis.com`
5. Verify URL has `alt=media&token=...` params

---

### ✅ Kingfisher Integration

```swift
// ✅ CORRECT: Use HTTPS URL from Firestore
KFImage(viewModel.photoURL) // photoURL is HTTPS download URL
    .placeholder {
        ActivityIndicatorView(isVisible: .constant(true), type: .default)
    }
    .retry(maxCount: 3, interval: .seconds(2))
    .cacheOriginalImage()
    .fade(duration: 0.25)

// ❌ WRONG: Don't try to use StorageReference directly
// KFImage(storageRef) // This won't work!
```

**Verification Steps:**
1. Profile picture displays correctly
2. Loading indicator shows while downloading
3. Image cached (subsequent loads instant)
4. Retry works on network failure
5. Placeholder shows if no URL

---

## QA Test Cases

### Test Case 1: Upload & Display Flow

**Steps:**
1. User taps profile picture → Opens image picker
2. User selects image (e.g., 3MB JPEG)
3. `StorageService.uploadImage()` is called
4. Image compressed to 0.7 quality
5. Uploaded to `profile_pictures/{userId}/profile.jpg`
6. Returns HTTPS download URL
7. URL saved to Firestore `/users/{userId}/photoURL`
8. Kingfisher loads image from URL
9. Image displays with fade-in animation

**Expected Results:**
- ✅ Loading indicator shows during upload
- ✅ URL format: `https://firebasestorage.googleapis.com/...`
- ✅ Image displays correctly (not broken)
- ✅ Image cached (instant reload)
- ✅ Success toast appears (using PopupView)

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

### Test Case 2: URL Accessibility (Public Read)

**Steps:**
1. Upload profile picture
2. Get download URL from Firestore
3. Open URL in web browser (Safari)
4. Open URL in different device/simulator
5. Clear Kingfisher cache, reload image

**Expected Results:**
- ✅ Image loads in browser without authentication
- ✅ Image loads on different device
- ✅ Image reloads after cache clear
- ✅ URL remains valid after app restart

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

### Test Case 3: Error Handling

**Scenario 3a: File Too Large**
- Upload 10MB image
- Expected: Error "Image is too large. Maximum size is 5MB."
- ActivityIndicator stops, error toast shows

**Scenario 3b: Network Failure**
- Enable airplane mode during upload
- Expected: Error "Network error. Please try again."
- Retry logic kicks in (Kingfisher)

**Scenario 3c: Invalid URL**
- Manually set photoURL to gs:// URL in Firestore
- Expected: Kingfisher shows placeholder, logs error
- App doesn't crash

**Scenario 3d: Missing Image**
- URL points to deleted file
- Expected: Kingfisher shows placeholder after retries
- No crash

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

### Test Case 4: Loading States & UX

**Upload Loading:**
- ✅ ActivityIndicatorView appears on upload start
- ✅ Semi-transparent overlay shows on profile picture
- ✅ "Uploading..." text visible
- ✅ Save button disabled during upload
- ✅ Loading indicator disappears on complete/error

**Download Loading:**
- ✅ Placeholder shows while image downloads
- ✅ Smooth fade-in animation when loaded
- ✅ No jarring layout shifts
- ✅ Cached images load instantly (no placeholder flash)

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

### Test Case 5: Caching Performance

**Steps:**
1. Upload profile picture
2. Navigate away from ProfileView
3. Navigate back to ProfileView
4. Observe: Image loads instantly (from cache)
5. Kill app, reopen
6. Observe: Image loads instantly (from disk cache)

**Expected Results:**
- ✅ First load: Shows placeholder, then image
- ✅ Subsequent loads: Instant (no placeholder)
- ✅ After app restart: Instant from disk cache
- ✅ Network request only on first load

**Performance Metrics:**
- First load: ~500-1000ms (depending on network)
- Cached load: <50ms (memory cache)
- Disk cached: <100ms

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

## Security Rules Validation

### Test Case 6: Storage Rules Enforcement

**Scenario 6a: Upload to Own Folder (Should Succeed)**
```swift
// User uid = "user123"
// Upload to: profile_pictures/user123/profile.jpg
// Expected: ✅ SUCCESS
```

**Scenario 6b: Upload to Other User's Folder (Should Fail)**
```swift
// User uid = "user123"
// Upload to: profile_pictures/user456/profile.jpg
// Expected: ❌ PERMISSION DENIED
```

**Scenario 6c: Upload Non-Image File (Should Fail)**
```swift
// Upload PDF to profile_pictures/user123/doc.pdf
// Expected: ❌ PERMISSION DENIED (not image/*)
```

**Scenario 6d: Upload >5MB File (Should Fail)**
```swift
// Upload 10MB image
// Expected: ❌ PERMISSION DENIED (exceeds 5MB limit)
```

**Actual Results:** _(To be filled during implementation)_
- [ ] PASS
- [ ] FAIL: _______________

---

## Common Issues & Solutions

### Issue: Image Not Displaying

**Possible Causes:**
1. ❌ Using gs:// URL instead of HTTPS URL
   - **Fix:** Call `storageRef.downloadURL()` and use that
2. ❌ URL is nil or empty string
   - **Fix:** Check Firestore has valid photoURL
3. ❌ Network issue or Storage Rules blocking read
   - **Fix:** Check Storage Rules allow public read
4. ❌ Kingfisher not imported
   - **Fix:** Add `import Kingfisher` to view file

---

### Issue: Upload Failing

**Possible Causes:**
1. ❌ File too large (>5MB)
   - **Fix:** Increase compression or enforce smaller size
2. ❌ Storage Rules blocking write
   - **Fix:** Verify user authenticated & path matches `{userId}`
3. ❌ Network timeout
   - **Fix:** Show retry option, check Firebase quota

---

### Issue: Slow Loading

**Possible Causes:**
1. ❌ Not using Kingfisher caching
   - **Fix:** Use `.cacheOriginalImage()` modifier
2. ❌ Large uncompressed images
   - **Fix:** Compress to 0.7 quality on upload
3. ❌ Poor network connection
   - **Fix:** Show loading indicator, implement retry

---

## Final Verification Checklist

Before marking Story 1.5 as complete:

- [ ] ✅ Upload returns HTTPS URL (not gs://)
- [ ] ✅ Image displays correctly with Kingfisher
- [ ] ✅ Loading indicators show during upload/download
- [ ] ✅ Images cached (instant subsequent loads)
- [ ] ✅ Errors handled gracefully (no crashes)
- [ ] ✅ Storage Rules enforce security (5MB, images only, own folder)
- [ ] ✅ URL accessible from browser/other devices
- [ ] ✅ Smooth UX (fade-in, no layout shifts)
- [ ] ✅ ProfileViewModel state management correct
- [ ] ✅ Success/error toasts using PopupView

---

## Production Readiness

### Performance Checklist:
- [ ] Images compressed on upload (0.7 quality)
- [ ] Cache-Control header set (1 year)
- [ ] Kingfisher disk & memory cache enabled
- [ ] Retry logic for failed downloads (3 retries)
- [ ] Placeholder shown during loading

### Security Checklist:
- [ ] Storage Rules enforce max 5MB
- [ ] Only image/* MIME types allowed
- [ ] Users can only upload to their own folder
- [ ] Download URLs include security tokens
- [ ] Public read access (anyone can view profile pics)

### UX Checklist:
- [ ] Loading indicators on all async operations
- [ ] Success toasts on upload complete
- [ ] Error toasts with actionable messages
- [ ] Smooth animations (fade-in)
- [ ] No jarring layout shifts

---

## Test Results Summary

**Tested By:** _____________
**Date:** _____________
**Build:** _____________

**Overall Status:**
- [ ] ✅ PASS - Ready for production
- [ ] ⚠️ PASS WITH ISSUES - Note issues below
- [ ] ❌ FAIL - Blocking issues found

**Issues Found:**
1. _______________
2. _______________
3. _______________

**Notes:**
_______________
_______________
_______________

---

**Sign-off:** This QA test validates that Firebase Storage integration meets production quality standards for Epic 1, Story 1.5.
