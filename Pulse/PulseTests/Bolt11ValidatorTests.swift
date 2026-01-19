//
//  Bolt11ValidatorTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class Bolt11ValidatorTests: XCTestCase {
    func testRejectsOverlongInvoice() {
        let longInvoice = "lnbc" + String(repeating: "a", count: 5000)
        XCTAssertThrowsError(try Bolt11Validator.validate(longInvoice))
    }

    func testRejectsInvalidAmountInvoice() {
        let invoice = "lnbc1" + String(repeating: "a", count: 20)
        XCTAssertThrowsError(try Bolt11Validator.validate(invoice))
    }
}
