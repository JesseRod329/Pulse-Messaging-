//
//  ProductionSecurityTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class ProductionSecurityTests: XCTestCase {
    func testZapReceiptSignatureValidationBlocksTampering() throws {
        guard let identity = NostrIdentity.create() else {
            XCTFail("Failed to create identity")
            return
        }

        var event = try NostrEvent.createSigned(
            identity: identity,
            kind: .zapReceipt,
            content: "",
            tags: [["amount", "1000"]]
        )

        event = NostrEvent(
            id: event.id,
            pubkey: event.pubkey,
            created_at: event.created_at,
            kind: event.kind,
            tags: event.tags,
            content: "tampered",
            sig: event.sig
        )

        XCTAssertThrowsError(try NostrEventValidator.validateZapReceipt(event))
    }

    func testScrubSensitiveStringsRedactsInvoices() {
        let message = "Invoice lightning:lnbc1qwerty and lnurl1abc123"
        let scrubbed = ErrorManager.scrubSensitiveStrings(message)
        XCTAssertFalse(scrubbed.contains("lnbc1"))
        XCTAssertFalse(scrubbed.contains("lnurl1"))
    }
}
