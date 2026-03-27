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
}
