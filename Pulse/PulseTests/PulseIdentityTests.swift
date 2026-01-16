//
//  PulseIdentityTests.swift
//  PulseTests
//
//  Unit tests for encryption and decryption logic
//

import XCTest
@testable import Pulse

@MainActor
final class PulseIdentityTests: XCTestCase {

    var identity: PulseIdentity!

    override func setUp() async throws {
        identity = PulseIdentity.create(handle: "@test_user")
    }

    override func tearDown() async throws {
        identity = nil
    }

    // MARK: - Identity Creation Tests

    func testIdentityCreation() {
        XCTAssertNotNil(identity)
        XCTAssertEqual(identity.handle, "@test_user")
        XCTAssertFalse(identity.publicKey.isEmpty)
        XCTAssertFalse(identity.signingPublicKey.isEmpty)
        XCTAssertTrue(identity.did.hasPrefix("did:key:z"))
    }

    func testDifferentIdentitiesHaveDifferentKeys() {
        let identity2 = PulseIdentity.create(handle: "@test_user_2")

        XCTAssertNotEqual(identity.publicKey, identity2.publicKey)
        XCTAssertNotEqual(identity.signingPublicKey, identity2.signingPublicKey)
        XCTAssertNotEqual(identity.did, identity2.did)
    }

    func testDIDFormat() {
        XCTAssertTrue(identity.did.hasPrefix("did:key:z"))
        XCTAssertGreaterThanOrEqual(identity.did.count, 50)
    }

    // MARK: - Encryption/Decryption Tests

    func testEncryptDecryptTextMessage() throws {
        let plaintext = "Hello, World!"

        let recipientKey = identity.publicKey
        let encrypted = try identity.encrypt(plaintext, for: recipientKey)

        XCTAssertNotNil(encrypted)
        XCTAssertGreaterThan(encrypted.count, 0)
        XCTAssertNotEqual(encrypted, plaintext.data(using: .utf8))

        let decrypted = try identity.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptCodeSnippet() throws {
        let code = """
        func hello() {
            print("Hello from Pulse!")
        }
        """

        let encrypted = try identity.encrypt(code, for: identity.publicKey)
        let decrypted = try identity.decrypt(encrypted)

        XCTAssertEqual(decrypted, code)
    }

    func testEncryptDecryptLongMessage() throws {
        let longText = String(repeating: "This is a test message. ", count: 100)

        let encrypted = try identity.encrypt(longText, for: identity.publicKey)
        let decrypted = try identity.decrypt(encrypted)

        XCTAssertEqual(decrypted, longText)
    }

    func testEncryptDecryptSpecialCharacters() throws {
        let specialChars = "Hello 🌍! Ñoño café français 日本語"

        let encrypted = try identity.encrypt(specialChars, for: identity.publicKey)
        let decrypted = try identity.decrypt(encrypted)

        XCTAssertEqual(decrypted, specialChars)
    }

    func testDifferentEncryptionsOfSameTextProduceDifferentCiphertexts() throws {
        let plaintext = "Same text"

        let encrypted1 = try identity.encrypt(plaintext, for: identity.publicKey)
        let encrypted2 = try identity.encrypt(plaintext, for: identity.publicKey)

        XCTAssertNotEqual(encrypted1, encrypted2,
                       "Each encryption should produce different ciphertext due to ephemeral keys")
    }

    // MARK: - Cross-Identity Tests

    func testEncryptWithIdentityDecryptWithAnother() throws {
        let senderIdentity = PulseIdentity.create(handle: "@alice")
        let recipientIdentity = PulseIdentity.create(handle: "@bob")

        let plaintext = "Secret message from Alice to Bob"

        let encrypted = try senderIdentity.encrypt(plaintext, for: recipientIdentity.publicKey)
        let decrypted = try recipientIdentity.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testCannotDecryptWithWrongIdentity() throws {
        let alice = PulseIdentity.create(handle: "@alice")
        let bob = PulseIdentity.create(handle: "@bob")
        let charlie = PulseIdentity.create(handle: "@charlie")

        let plaintext = "Message for Bob"
        let encrypted = try alice.encrypt(plaintext, for: bob.publicKey)

        XCTAssertThrowsError(try charlie.decrypt(encrypted)) { error in
            if let cryptoError = error as? CryptoError {
                XCTAssertTrue(true)
            }
        }
    }

    // MARK: - Error Handling Tests

    func testDecryptInvalidDataThrowsError() {
        let invalidData = Data([0, 1, 2, 3])

        XCTAssertThrowsError(try identity.decrypt(invalidData)) { error in
            XCTAssertNotNil(error)
        }
    }

    func testDecryptEmptyDataThrowsError() {
        let emptyData = Data()

        XCTAssertThrowsError(try identity.decrypt(emptyData)) { error in
            XCTAssertEqual(error as? CryptoError, .invalidCiphertext)
        }
    }

    func testDecryptShortDataThrowsError() {
        let shortData = Data([0, 1, 2])

        XCTAssertThrowsError(try identity.decrypt(shortData)) { error in
            XCTAssertEqual(error as? CryptoError, .invalidCiphertext)
        }
    }

    // MARK: - Base58 Encoding Tests

    func testBase58EncodingRoundtrip() {
        let testData = Data([0x00, 0x01, 0x02, 0xFF, 0xAB, 0xCD])
        let encoded = testData.base58EncodedString()

        XCTAssertNotNil(encoded)
        XCTAssertGreaterThan(encoded.count, 0)

        let decoded = Data.base58Decoded(encoded)
        XCTAssertEqual(decoded, testData)
    }

    func testBase58EncodingEmptyData() {
        let emptyData = Data()
        let encoded = emptyData.base58EncodedString()

        XCTAssertEqual(encoded, "")

        let decoded = Data.base58Decoded(encoded)
        XCTAssertEqual(decoded, emptyData)
    }

    func testBase58EncodingLeadingZeros() {
        var data = Data([0x00, 0x00, 0x01, 0x02])
        let encoded = data.base58EncodedString()

        XCTAssertTrue(encoded.hasPrefix("11"))

        let decoded = Data.base58Decoded(encoded)
        XCTAssertEqual(decoded, data)
    }

    // MARK: - Performance Tests

    func testEncryptionPerformance() throws {
        let plaintext = "Performance test message with reasonable length"
        measure {
            _ = try? identity.encrypt(plaintext, for: identity.publicKey)
        }
    }

    func testDecryptionPerformance() throws {
        let plaintext = "Performance test message with reasonable length"
        let encrypted = try identity.encrypt(plaintext, for: identity.publicKey)

        measure {
            _ = try? identity.decrypt(encrypted)
        }
    }

    func testBulkEncryptionDecryption() throws {
        let messages = (0..<100).map { "Message #\($0)" }

        measure {
            for message in messages {
                let encrypted = try? identity.encrypt(message, for: identity.publicKey)
                let decrypted = try? identity.decrypt(encrypted ?? Data())
                XCTAssertEqual(decrypted, message)
            }
        }
    }

    // MARK: - Keychain Storage Tests

    func testKeychainSaveAndLoad() throws {
        let testIdentity = PulseIdentity.create(handle: "@keychain_test")

        let saved = testIdentity.saveToKeychain()
        XCTAssertTrue(saved)

        let loaded = PulseIdentity.loadFromKeychain()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.handle, testIdentity.handle)
        XCTAssertEqual(loaded?.publicKey, testIdentity.publicKey)
    }

    func testKeychainDelete() throws {
        let testIdentity = PulseIdentity.create(handle: "@delete_test")
        _ = testIdentity.saveToKeychain()

        let deleted = PulseIdentity.deleteFromKeychain()
        XCTAssertTrue(deleted)

        let loaded = PulseIdentity.loadFromKeychain()
        XCTAssertNil(loaded)
    }

    func testKeychainLoadWhenEmpty() {
        let loaded = PulseIdentity.loadFromKeychain()
        XCTAssertNil(loaded)
    }
}
