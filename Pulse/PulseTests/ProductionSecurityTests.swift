//
//  ProductionSecurityTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class ProductionSecurityTests: XCTestCase {
    @MainActor func testScrubSensitiveStringsRedactsInvoices() {
        let message = "Invoice lightning:lnbc1qwerty and lnurl1abc123"
        let scrubbed = ErrorManager.scrubSensitiveStrings(message)
        XCTAssertFalse(scrubbed.contains("lnbc1"))
        XCTAssertFalse(scrubbed.contains("lnurl1"))
    }
}
