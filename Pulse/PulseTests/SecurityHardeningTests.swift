//
//  SecurityHardeningTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class SecurityHardeningTests: XCTestCase {
    func testRelayFloodIsRateLimited() {
        var limiter = RateLimiter(maxEvents: 5, interval: 1, start: Date(timeIntervalSince1970: 0))
        for i in 0..<5 {
            XCTAssertTrue(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.1 + Double(i) * 0.01)))
        }
        XCTAssertFalse(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.2)))
    }

    func testInvoiceTooLongRejected() {
        let longInvoice = "lnbc" + String(repeating: "a", count: 5000)
        XCTAssertThrowsError(try Bolt11Validator.validate(longInvoice))
    }

    func testZapSecurityGuardRejectsMissingDescriptionHash() {
        let event = NostrEvent(
            id: "id",
            pubkey: String(repeating: "a", count: 64),
            created_at: 100,
            kind: NostrEventKind.zapRequest.rawValue,
            tags: [["amount", "2000"]],
            content: "",
            sig: String(repeating: "0", count: 128)
        )

        let invoice = Bolt11Invoice(
            raw: "lnbc-test",
            hrp: "lnbc",
            network: .bitcoin,
            amountMillisats: 2000,
            timestamp: Date(timeIntervalSince1970: 100),
            tags: [
                .paymentHash(Data(repeating: 0x01, count: 32))
            ],
            signature: Data(repeating: 0x00, count: 65)
        )

        XCTAssertThrowsError(
            try ZapSecurityGuard.validate(
                invoice: invoice,
                zapRequest: event,
                expectedAmountMsat: 2000,
                now: Date(timeIntervalSince1970: 200)
            )
        )
    }
}
