/// AuthServiceTests.swift
/// Unit tests for AuthService validation logic
/// [Source: Epic 1, Story 1.1]
///
/// Tests display name validation, email validation, and password validation

import XCTest
@testable import buzzbox

@MainActor
final class AuthServiceTests: XCTestCase {
    var sut: AuthService!

    override func setUp() {
        super.setUp()
        sut = AuthService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Display Name Validation Tests

    func testValidDisplayName() {
        XCTAssertTrue(sut.isValidDisplayName("john_doe"))
        XCTAssertTrue(sut.isValidDisplayName("jane.smith"))
        XCTAssertTrue(sut.isValidDisplayName("user123"))
        XCTAssertTrue(sut.isValidDisplayName("abc"))
        XCTAssertTrue(sut.isValidDisplayName("a".replacingOccurrences(of: "a", with: String(repeating: "a", count: 30))))
    }

    func testDisplayNameTooShort() {
        XCTAssertFalse(sut.isValidDisplayName("ab"))
        XCTAssertFalse(sut.isValidDisplayName("a"))
        XCTAssertFalse(sut.isValidDisplayName(""))
    }

    func testDisplayNameTooLong() {
        let longName = String(repeating: "a", count: 31)
        XCTAssertFalse(sut.isValidDisplayName(longName))
    }

    func testDisplayNameInvalidCharacters() {
        XCTAssertFalse(sut.isValidDisplayName("user@name"))
        XCTAssertFalse(sut.isValidDisplayName("user name"))
        XCTAssertFalse(sut.isValidDisplayName("user-name"))
        XCTAssertFalse(sut.isValidDisplayName("user#name"))
    }

    func testDisplayNameStartsWithPeriod() {
        XCTAssertFalse(sut.isValidDisplayName(".username"))
    }

    func testDisplayNameEndsWithPeriod() {
        XCTAssertFalse(sut.isValidDisplayName("username."))
    }

    func testDisplayNameConsecutivePeriods() {
        XCTAssertFalse(sut.isValidDisplayName("user..name"))
        XCTAssertFalse(sut.isValidDisplayName("user...name"))
    }

    func testDisplayNameSinglePeriod() {
        XCTAssertTrue(sut.isValidDisplayName("user.name"))
    }

    // MARK: - Email Validation Tests

    func testValidEmail() {
        XCTAssertTrue(sut.isValidEmail("user@example.com"))
        XCTAssertTrue(sut.isValidEmail("test.user@example.co.uk"))
        XCTAssertTrue(sut.isValidEmail("user+tag@example.com"))
    }

    func testInvalidEmail() {
        XCTAssertFalse(sut.isValidEmail("invalid"))
        XCTAssertFalse(sut.isValidEmail("invalid@"))
        XCTAssertFalse(sut.isValidEmail("@example.com"))
        XCTAssertFalse(sut.isValidEmail("invalid@example"))
        XCTAssertFalse(sut.isValidEmail(""))
    }

    // MARK: - Password Validation Tests

    func testValidPassword() {
        XCTAssertTrue(sut.isValidPassword("12345678"))
        XCTAssertTrue(sut.isValidPassword("password123"))
        XCTAssertTrue(sut.isValidPassword("verylongpassword"))
    }

    func testInvalidPassword() {
        XCTAssertFalse(sut.isValidPassword("1234567"))
        XCTAssertFalse(sut.isValidPassword("short"))
        XCTAssertFalse(sut.isValidPassword(""))
    }
}
