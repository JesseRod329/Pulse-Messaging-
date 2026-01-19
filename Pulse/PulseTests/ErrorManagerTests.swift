//
//  ErrorManagerTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class ErrorManagerTests: XCTestCase {
    func testScrubsSensitiveStrings() {
        let message = "Failed lnurl1abcdef and lightning:lnbc1deadbeef plus hash 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let scrubbed = ErrorManager.scrubSensitiveStrings(message)
        XCTAssertFalse(scrubbed.contains("lnurl1abcdef"))
        XCTAssertFalse(scrubbed.contains("lnbc1deadbeef"))
        XCTAssertFalse(scrubbed.contains("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))
    }
}
