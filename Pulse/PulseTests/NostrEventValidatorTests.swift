//
//  NostrEventValidatorTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class NostrEventValidatorTests: XCTestCase {
    func testValidZapRequestPasses() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .zapRequest,
            content: "",
            tags: [["amount", "1000"], ["p", "ff".padding(toLength: 64, withPad: "f", startingAt: 0)]]
        )

        XCTAssertNoThrow(try NostrEventValidator.validateZapRequest(event))
    }

    func testInvalidSignatureFails() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        var event = try NostrEvent.createSigned(
            identity: identity,
            kind: .zapRequest,
            content: "",
            tags: [["amount", "1000"]]
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

        XCTAssertThrowsError(try NostrEventValidator.validateZapRequest(event))
    }

    func testInvalidKindFails() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        let event = try NostrEvent.createSigned(
            identity: identity,
            kind: .textNote,
            content: "",
            tags: []
        )

        XCTAssertThrowsError(try NostrEventValidator.validateZapRequest(event))
    }

    func testInvalidEventIdFails() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        var event = try NostrEvent.createSigned(
            identity: identity,
            kind: .zapReceipt,
            content: "",
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

        XCTAssertThrowsError(try NostrEventValidator.validateZapReceipt(event))
    }
}
