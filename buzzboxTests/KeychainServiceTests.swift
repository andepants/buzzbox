/// KeychainServiceTests.swift
/// Unit tests for KeychainService
/// [Source: Epic 1, Story 1.2]
///
/// Tests secure token storage, retrieval, and deletion in iOS Keychain

import XCTest
@testable import buzzbox

final class KeychainServiceTests: XCTestCase {
    var sut: KeychainService!

    override func setUp() {
        super.setUp()
        sut = KeychainService()

        // Clean up any existing tokens from previous tests
        try? sut.delete()
    }

    override func tearDown() {
        // Clean up after tests
        try? sut.delete()
        sut = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveToken() throws {
        // Given
        let token = "test_auth_token_12345"

        // When
        try sut.save(token: token)

        // Then
        let retrievedToken = sut.retrieve()
        XCTAssertEqual(retrievedToken, token)
    }

    func testSaveOverwritesExistingToken() throws {
        // Given
        let firstToken = "first_token"
        let secondToken = "second_token"

        // When
        try sut.save(token: firstToken)
        try sut.save(token: secondToken)

        // Then
        let retrievedToken = sut.retrieve()
        XCTAssertEqual(retrievedToken, secondToken)
    }

    // MARK: - Retrieve Tests

    func testRetrieveNonExistentToken() {
        // Given - no token saved

        // When
        let retrievedToken = sut.retrieve()

        // Then
        XCTAssertNil(retrievedToken)
    }

    func testRetrieveAfterSave() throws {
        // Given
        let token = "valid_auth_token"
        try sut.save(token: token)

        // When
        let retrievedToken = sut.retrieve()

        // Then
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken, token)
    }

    // MARK: - Delete Tests

    func testDeleteToken() throws {
        // Given
        let token = "token_to_delete"
        try sut.save(token: token)

        // When
        try sut.delete()

        // Then
        let retrievedToken = sut.retrieve()
        XCTAssertNil(retrievedToken)
    }

    func testDeleteNonExistentToken() {
        // Given - no token saved

        // When/Then - should not throw
        XCTAssertNoThrow(try sut.delete())
    }

    // MARK: - Edge Cases

    func testSaveEmptyToken() throws {
        // Given
        let emptyToken = ""

        // When
        try sut.save(token: emptyToken)

        // Then
        let retrievedToken = sut.retrieve()
        XCTAssertEqual(retrievedToken, emptyToken)
    }

    func testSaveLongToken() throws {
        // Given - simulate a very long JWT token
        let longToken = String(repeating: "a", count: 1000)

        // When
        try sut.save(token: longToken)

        // Then
        let retrievedToken = sut.retrieve()
        XCTAssertEqual(retrievedToken, longToken)
    }

    func testMultipleSaveDeleteCycles() throws {
        // Given
        let tokens = ["token1", "token2", "token3"]

        for token in tokens {
            // When - save and verify
            try sut.save(token: token)
            XCTAssertEqual(sut.retrieve(), token)

            // Then - delete and verify
            try sut.delete()
            XCTAssertNil(sut.retrieve())
        }
    }
}
