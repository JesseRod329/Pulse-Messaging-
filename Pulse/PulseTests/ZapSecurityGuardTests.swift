//
//  ZapSecurityGuardTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class ZapSecurityGuardTests: XCTestCase {
    func testValidInvoicePassesGuard() throws {
        let event = NostrEvent(
            id: "id",
            pubkey: "abcdef0123456789",
            created_at: 100,
            kind: NostrEventKind.zapRequest.rawValue,
            tags: [["amount", "2000"]],
            content: "",
            sig: ""
        )
        let hashHex = try event.descriptionHash()
        guard let hashData = Data(hex: hashHex) else {
            XCTFail("Failed to decode hash")
            return
        }

        let invoice = Bolt11Invoice(
            raw: "lnbc-test",
            hrp: "lnbc",
            network: .bitcoin,
            amountMillisats: 2000,
            timestamp: Date(timeIntervalSince1970: 100),
            tags: [
                .paymentHash(Data(repeating: 0x01, count: 32)),
                .descriptionHash(hashData),
                .expiry(3600)
            ],
            signature: Data(repeating: 0x00, count: 65)
        )

        XCTAssertNoThrow(
            try ZapSecurityGuard.validate(
                invoice: invoice,
                zapRequest: event,
                expectedAmountMsat: 2000,
                now: Date(timeIntervalSince1970: 200)
            )
        )
    }

    func testAmountMismatchThrows() throws {
        let event = NostrEvent(
            id: "id",
            pubkey: "abcdef0123456789",
            created_at: 100,
            kind: NostrEventKind.zapRequest.rawValue,
            tags: [["amount", "2000"]],
            content: "",
            sig: ""
        )
        let hashHex = try event.descriptionHash()
        guard let hashData = Data(hex: hashHex) else {
            XCTFail("Failed to decode hash")
            return
        }

        let invoice = Bolt11Invoice(
            raw: "lnbc-test",
            hrp: "lnbc",
            network: .bitcoin,
            amountMillisats: 1000,
            timestamp: Date(timeIntervalSince1970: 100),
            tags: [
                .paymentHash(Data(repeating: 0x01, count: 32)),
                .descriptionHash(hashData),
                .expiry(3600)
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

    func testMissingDescriptionHashThrows() {
        let event = NostrEvent(
            id: "id",
            pubkey: "abcdef0123456789",
            created_at: 100,
            kind: NostrEventKind.zapRequest.rawValue,
            tags: [["amount", "2000"]],
            content: "",
            sig: ""
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

    func testExpiredInvoiceThrows() throws {
        let event = NostrEvent(
            id: "id",
            pubkey: "abcdef0123456789",
            created_at: 100,
            kind: NostrEventKind.zapRequest.rawValue,
            tags: [["amount", "2000"]],
            content: "",
            sig: ""
        )
        let hashHex = try event.descriptionHash()
        guard let hashData = Data(hex: hashHex) else {
            XCTFail("Failed to decode hash")
            return
        }

        let invoice = Bolt11Invoice(
            raw: "lnbc-test",
            hrp: "lnbc",
            network: .bitcoin,
            amountMillisats: 2000,
            timestamp: Date(timeIntervalSince1970: 100),
            tags: [
                .paymentHash(Data(repeating: 0x01, count: 32)),
                .descriptionHash(hashData),
                .expiry(10)
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
