//
//  WalletURISanitizerTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class WalletURISanitizerTests: XCTestCase {
    func testSanitizeInvoiceStripsPrefix() {
        let sanitized = WalletURISanitizer.sanitizeInvoice("lightning:LNBC1TEST")
        XCTAssertEqual(sanitized, "lnbc1test")
    }

    func testSanitizeInvoiceRejectsInvalidChars() {
        let sanitized = WalletURISanitizer.sanitizeInvoice("lnbc1test<script>")
        XCTAssertNil(sanitized)
    }

    func testSanitizeInvoiceRejectsMissingPrefix() {
        let sanitized = WalletURISanitizer.sanitizeInvoice("bitcoin:123")
        XCTAssertNil(sanitized)
    }

    func testBuildPaymentURLForPhoenix() {
        let url = WalletURISanitizer.buildPaymentURL(invoice: "lnbc1test", wallet: .phoenix)
        XCTAssertEqual(url?.scheme, "phoenix")
    }

    func testBuildGenericLightningURL() {
        let url = WalletURISanitizer.buildGenericLightningURL(invoice: "lnbc1test")
        XCTAssertEqual(url?.scheme, "lightning")
    }
}
