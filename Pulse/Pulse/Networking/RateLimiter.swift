//
//  RateLimiter.swift
//  Pulse
//
//  Simple fixed-window rate limiter for network defenses.
//

import Foundation

struct RateLimiter {
    private let maxEvents: Int
    private let interval: TimeInterval
    private var windowStart: Date
    private var count: Int

    init(maxEvents: Int, interval: TimeInterval, start: Date = Date()) {
        self.maxEvents = maxEvents
        self.interval = interval
        self.windowStart = start
        self.count = 0
    }

    mutating func shouldAllow(now: Date = Date()) -> Bool {
        if now.timeIntervalSince(windowStart) >= interval {
            windowStart = now
            count = 0
        }

        guard count < maxEvents else {
            return false
        }

        count += 1
        return true
    }
}
