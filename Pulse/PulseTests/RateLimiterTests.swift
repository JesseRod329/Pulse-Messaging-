//
//  RateLimiterTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class RateLimiterTests: XCTestCase {
    func testAllowsWithinWindow() {
        var limiter = RateLimiter(maxEvents: 2, interval: 1, start: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.1)))
        XCTAssertTrue(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.2)))
        XCTAssertFalse(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.3)))
    }

    func testResetsAfterInterval() {
        var limiter = RateLimiter(maxEvents: 1, interval: 1, start: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.1)))
        XCTAssertFalse(limiter.shouldAllow(now: Date(timeIntervalSince1970: 0.2)))
        XCTAssertTrue(limiter.shouldAllow(now: Date(timeIntervalSince1970: 1.2)))
    }
}
