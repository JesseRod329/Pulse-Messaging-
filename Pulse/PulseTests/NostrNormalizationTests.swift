//
//  NostrNormalizationTests.swift
//  PulseTests
//

import XCTest
import CryptoKit
@testable import Pulse

final class NostrNormalizationTests: XCTestCase {
    func testCanonicalEventJSON() throws {
        let pubkey = "abcdef0123456789"
        let createdAt = 123
        let kind = NostrEventKind.textNote.rawValue
        let tags = [["p", "recipient"], ["amount", "1000"], ["relays", "wss://relay.example"]]
        let content = "hello"

        let canonical = try NostrNormalization.canonicalEventJSONString(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content
        )

        let expected = "[0,\"abcdef0123456789\",123,1,[[\"p\",\"recipient\"],[\"amount\",\"1000\"],[\"relays\",\"wss:\\/\\/relay.example\"]],\"hello\"]"
        XCTAssertEqual(canonical, expected)
    }

    func testDescriptionHashMatchesCanonicalJSON() throws {
        let event = NostrEvent(
            id: "",
            pubkey: "abcdef0123456789",
            created_at: 123,
            kind: NostrEventKind.textNote.rawValue,
            tags: [["p", "recipient"], ["amount", "1000"]],
            content: "hello",
            sig: ""
        )

        let canonical = try event.normalizedEventJSONString()
        let canonicalHash = SHA256.hash(data: Data(canonical.utf8))
        let expected = canonicalHash.compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(try event.descriptionHash(), expected)
    }
}
