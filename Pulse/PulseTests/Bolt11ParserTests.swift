//
//  Bolt11ParserTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class Bolt11ParserTests: XCTestCase {
    func testParseValidInvoice() throws {
        let invoice = "lnbc20u1pvjluezhp58yjmdan79s6qqdhdzgynm4zwqd5d7xmw5fk98klysy043l2ahrqspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqfppqw508d6qejxtdg4y5r3zarvary0c5xw7kepvrhrm9s57hejg0p662ur5j5cr03890fa7k2pypgttmh4897d3raaq85a293e9jpuqwl0rnfuwzam7yr8e690nd2ypcq9hlkdwdvycqa0qza8"

        let parsed = try Bolt11Parser().parse(invoice)

        XCTAssertEqual(parsed.network, .bitcoin)
        XCTAssertEqual(parsed.amountMillisats, 2_000_000)
        XCTAssertNotNil(parsed.paymentHash)
        XCTAssertTrue(parsed.description != nil || parsed.descriptionHash != nil)
    }

    func testInvalidBech32Fails() {
        XCTAssertThrowsError(try Bolt11Parser().parse("lnbcinvalidinvoice"))
    }

    func testUnsafeDescriptionDetection() {
        XCTAssertFalse(Bolt11Validator.isSafeDescription("<script>alert('xss')</script>"))
        XCTAssertFalse(Bolt11Validator.isSafeDescription("DROP TABLE zaps;"))
        XCTAssertTrue(Bolt11Validator.isSafeDescription("Thanks for the zap!"))
    }
}
