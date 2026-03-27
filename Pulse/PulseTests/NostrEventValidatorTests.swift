//
//  NostrEventValidatorTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class NostrEventValidatorTests: XCTestCase {
    func testValidSignaturePasses() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .textNote,
            content: "hello",
            tags: []
        )

        XCTAssertNoThrow(try NostrEventValidator.validateEventSignature(event))
    }

    func testInvalidSignatureFails() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        var event = try NostrEvent.createSigned(
            identity: identity,
            kind: .textNote,
            content: "hello",
            tags: []
        )
        event = NostrEvent(
            id: event.id,
            pubkey: event.pubkey,
            created_at: event.created_at,
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            sig: String(repeating: "0", count: 128)
        )

        XCTAssertThrowsError(try NostrEventValidator.validateEventSignature(event))
    }

    func testInvalidEventIdFails() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        var event = try NostrEvent.createSigned(
            identity: identity,
            kind: .textNote,
            content: "hello",
            tags: []
        )

        event = NostrEvent(
            id: String(repeating: "0", count: 64),
            pubkey: event.pubkey,
            created_at: event.created_at,
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            sig: event.sig
        )

        XCTAssertThrowsError(try NostrEventValidator.validateEventSignature(event))
    }
}
