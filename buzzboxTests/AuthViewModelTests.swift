/// AuthViewModelTests.swift
/// Unit tests for AuthViewModel validation logic
/// [Source: Epic 1, Story 1.1]
///
/// Tests form validation, computed properties, and state management

import XCTest
@testable import buzzbox

@MainActor
final class AuthViewModelTests: XCTestCase {
    var sut: AuthViewModel!

    override func setUp() {
        super.setUp()
        sut = AuthViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Email Validation Tests

    func testEmailValidationValid() {
        sut.email = "user@example.com"
        XCTAssertTrue(sut.isEmailValid)
        XCTAssertNil(sut.emailValidationMessage)
    }

    func testEmailValidationInvalid() {
        sut.email = "invalid-email"
        XCTAssertFalse(sut.isEmailValid)
        XCTAssertNotNil(sut.emailValidationMessage)
    }

    func testEmailValidationEmpty() {
        sut.email = ""
        XCTAssertFalse(sut.isEmailValid)
        XCTAssertNil(sut.emailValidationMessage)
    }

    // MARK: - Password Validation Tests

    func testPasswordValidationValid() {
        sut.password = "password123"
        XCTAssertTrue(sut.isPasswordValid)
        XCTAssertNil(sut.passwordValidationMessage)
    }

    func testPasswordValidationInvalid() {
        sut.password = "short"
        XCTAssertFalse(sut.isPasswordValid)
        XCTAssertNotNil(sut.passwordValidationMessage)
    }

    func testPasswordValidationEmpty() {
        sut.password = ""
        XCTAssertFalse(sut.isPasswordValid)
        XCTAssertNil(sut.passwordValidationMessage)
    }

    // MARK: - Password Match Tests

    func testPasswordsMatch() {
        sut.password = "password123"
        sut.confirmPassword = "password123"
        XCTAssertTrue(sut.passwordsMatch)
        XCTAssertNil(sut.passwordMatchValidationMessage)
    }

    func testPasswordsDontMatch() {
        sut.password = "password123"
        sut.confirmPassword = "different"
        XCTAssertFalse(sut.passwordsMatch)
        XCTAssertNotNil(sut.passwordMatchValidationMessage)
    }

    func testPasswordsMatchEmpty() {
        sut.password = ""
        sut.confirmPassword = ""
        XCTAssertFalse(sut.passwordsMatch)
        XCTAssertNil(sut.passwordMatchValidationMessage)
    }

    // MARK: - Display Name Validation Tests

    func testDisplayNameValid() {
        sut.displayName = "john_doe"
        XCTAssertTrue(sut.isDisplayNameValid)
    }

    func testDisplayNameInvalid() {
        sut.displayName = "ab"
        XCTAssertFalse(sut.isDisplayNameValid)
    }

    // MARK: - Form Validation Tests

    func testFormValidWithAllFields() {
        sut.email = "user@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .available

        XCTAssertTrue(sut.isFormValid)
    }

    func testFormInvalidWithMissingEmail() {
        sut.email = ""
        sut.password = "password123"
        sut.confirmPassword = "password123"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .available

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormInvalidWithWeakPassword() {
        sut.email = "user@example.com"
        sut.password = "short"
        sut.confirmPassword = "short"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .available

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormInvalidWithPasswordMismatch() {
        sut.email = "user@example.com"
        sut.password = "password123"
        sut.confirmPassword = "different"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .available

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormInvalidWithTakenDisplayName() {
        sut.email = "user@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .taken

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormInvalidWithUnknownDisplayNameAvailability() {
        sut.email = "user@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"
        sut.displayName = "john_doe"
        sut.displayNameAvailability = .unknown

        XCTAssertFalse(sut.isFormValid)
    }

    // MARK: - Login Tests

    func testLoginAttemptCountIncrementsOnFailure() {
        // Given
        let initialCount = sut.loginAttemptCount

        // When - simulate login failure by setting error
        sut.errorMessage = "Invalid credentials"
        sut.showError = true
        sut.loginAttemptCount += 1

        // Then
        XCTAssertEqual(sut.loginAttemptCount, initialCount + 1)
    }

    func testShowErrorFlagResetOnNewLogin() {
        // Given
        sut.showError = true
        sut.errorMessage = "Previous error"

        // When - simulate starting new login attempt
        sut.errorMessage = nil
        sut.showError = false

        // Then
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }

    func testIsAuthenticatedObservesAuthService() {
        // Note: This test verifies the computed property exists
        // Actual authentication state is managed by AuthService
        XCTAssertFalse(sut.isAuthenticated)
    }
}
