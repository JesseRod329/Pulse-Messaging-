//
//  VirtualPeerFactory.swift
//  PulseTests
//
//  Factory for creating realistic virtual peers.
//

import Foundation
@testable import Pulse

/// Factory for generating virtual peers with realistic attributes
@MainActor
class VirtualPeerFactory {

    // Sample data for realistic peer generation
    private static let handlePrefixes = [
        "dev", "code", "hack", "swift", "rust", "py", "js", "go",
        "crypto", "ml", "data", "cloud", "infra", "mobile", "web"
    ]

    private static let handleSuffixes = [
        "ninja", "wizard", "guru", "master", "pro", "ace", "hacker",
        "builder", "maker", "crafter", "smith", "monk", "sage"
    ]

    private static let techStacks: [[String]] = [
        ["Swift", "iOS", "SwiftUI"],
        ["Rust", "WebAssembly", "Systems"],
        ["Python", "ML", "TensorFlow"],
        ["TypeScript", "React", "Node"],
        ["Go", "Kubernetes", "Docker"],
        ["Kotlin", "Android", "Compose"],
        ["C++", "Graphics", "OpenGL"],
        ["Solidity", "Ethereum", "Web3"],
        ["Ruby", "Rails", "PostgreSQL"],
        ["Java", "Spring", "Microservices"]
    ]

    // MARK: - Single Peer Creation

    /// Create a single virtual peer with random attributes
    static func createPeer(
        id: String? = nil,
        handle: String? = nil,
        status: PeerStatus? = nil,
        position: SimulatedPosition? = nil,
        behavior: PeerBehavior? = nil,
        techStack: [String]? = nil
    ) -> VirtualPeer {
        let peerId = id ?? UUID().uuidString
        let peerHandle = handle ?? generateHandle()
        let peerStatus = status ?? randomStatus()
        let peerPosition = position ?? SimulatedPosition.random(maxRadius: 100)
        let peerBehavior = behavior ?? randomBehavior()
        let peerTechStack = techStack ?? randomTechStack()

        return VirtualPeer(
            id: peerId,
            handle: peerHandle,
            status: peerStatus,
            position: peerPosition,
            behavior: peerBehavior,
            techStack: peerTechStack
        )
    }

    // MARK: - Batch Creation

    /// Create multiple peers with mixed attributes
    static func createPeers(count: Int, maxRadius: Double = 100) -> [VirtualPeer] {
        (0..<count).map { _ in
            createPeer(position: SimulatedPosition.random(maxRadius: maxRadius))
        }
    }

    /// Create peers clustered around a center point
    static func createCluster(
        count: Int,
        center: SimulatedPosition,
        radius: Double = 20
    ) -> [VirtualPeer] {
        (0..<count).map { _ in
            let offset = SimulatedPosition.random(maxRadius: radius)
            let position = SimulatedPosition(
                x: center.x + offset.x,
                y: center.y + offset.y
            )
            return createPeer(position: position)
        }
    }

    /// Create peers with specific behavior distribution
    static func createWithBehaviors(
        responsive: Int = 0,
        slow: Int = 0,
        unreliable: Int = 0,
        intermittent: Int = 0,
        malicious: Int = 0
    ) -> [VirtualPeer] {
        var peers: [VirtualPeer] = []

        peers.append(contentsOf: (0..<responsive).map { _ in
            createPeer(behavior: .responsive)
        })
        peers.append(contentsOf: (0..<slow).map { _ in
            createPeer(behavior: .slow)
        })
        peers.append(contentsOf: (0..<unreliable).map { _ in
            createPeer(behavior: .unreliable)
        })
        peers.append(contentsOf: (0..<intermittent).map { _ in
            createPeer(behavior: .intermittent)
        })
        peers.append(contentsOf: (0..<malicious).map { _ in
            createPeer(behavior: .malicious)
        })

        return peers.shuffled()
    }

    // MARK: - Private Helpers

    private static func generateHandle() -> String {
        let prefix = handlePrefixes.randomElement() ?? "dev"
        let suffix = handleSuffixes.randomElement() ?? "pro"
        let number = Int.random(in: 1...999)
        return "\(prefix)_\(suffix)\(number)"
    }

    private static func randomStatus() -> PeerStatus {
        let rand = Double.random(in: 0...1)
        if rand < 0.6 {
            return .active
        } else if rand < 0.85 {
            return .flowState
        } else {
            return .idle
        }
    }

    private static func randomBehavior() -> PeerBehavior {
        // Weight towards responsive behavior
        let rand = Double.random(in: 0...1)
        if rand < 0.7 {
            return .responsive
        } else if rand < 0.85 {
            return .slow
        } else if rand < 0.95 {
            return .unreliable
        } else if rand < 0.98 {
            return .intermittent
        } else {
            return .malicious
        }
    }

    private static func randomTechStack() -> [String] {
        techStacks.randomElement() ?? ["Swift", "iOS"]
    }
}

// MARK: - Scenario-Based Factories

extension VirtualPeerFactory {

    /// Create peers for a coffee shop scenario (small, casual)
    static func coffeeShopScenario() -> [VirtualPeer] {
        let count = Int.random(in: 5...15)
        return createPeers(count: count, maxRadius: 30)
    }

    /// Create peers for a conference scenario (dense, clustered)
    static func conferenceScenario() -> [VirtualPeer] {
        var peers: [VirtualPeer] = []

        // Main hall cluster
        peers.append(contentsOf: createCluster(
            count: Int.random(in: 30...50),
            center: SimulatedPosition(x: 0, y: 0),
            radius: 50
        ))

        // Breakout room clusters
        for i in 0..<3 {
            let angle = Double(i) * (2 * .pi / 3)
            let center = SimulatedPosition(
                x: 80 * cos(angle),
                y: 80 * sin(angle)
            )
            peers.append(contentsOf: createCluster(
                count: Int.random(in: 10...20),
                center: center,
                radius: 15
            ))
        }

        return peers
    }

    /// Create peers for a hackathon (teams in separate areas)
    static func hackathonScenario() -> [VirtualPeer] {
        var peers: [VirtualPeer] = []
        let teamCount = Int.random(in: 5...8)

        for i in 0..<teamCount {
            let angle = Double(i) * (2 * .pi / Double(teamCount))
            let center = SimulatedPosition(
                x: 50 * cos(angle),
                y: 50 * sin(angle)
            )
            peers.append(contentsOf: createCluster(
                count: Int.random(in: 3...6),
                center: center,
                radius: 10
            ))
        }

        return peers
    }

    /// Create peers for commute scenario (sparse, high churn)
    static func commuteScenario() -> [VirtualPeer] {
        // Create a line of peers (like a train or bus)
        let count = Int.random(in: 10...20)
        return (0..<count).map { i in
            let position = SimulatedPosition(
                x: Double(i) * 2,  // 2 meters apart
                y: Double.random(in: -1...1)
            )
            // Higher intermittent behavior for commute
            let behavior: PeerBehavior = Double.random(in: 0...1) < 0.3 ? .intermittent : .responsive
            return createPeer(position: position, behavior: behavior)
        }
    }

    /// Create peers for office scenario (stable, star topology)
    static func officeScenario() -> [VirtualPeer] {
        var peers: [VirtualPeer] = []

        // Central hub (server room / common area)
        peers.append(contentsOf: createCluster(
            count: 5,
            center: SimulatedPosition.origin,
            radius: 10
        ))

        // Desk clusters around the perimeter
        for i in 0..<6 {
            let angle = Double(i) * (2 * .pi / 6)
            let center = SimulatedPosition(
                x: 30 * cos(angle),
                y: 30 * sin(angle)
            )
            peers.append(contentsOf: createCluster(
                count: Int.random(in: 3...5),
                center: center,
                radius: 8
            ))
        }

        return peers
    }

    /// Create peers for stress testing (maximum load)
    static func stressScenario(peerCount: Int = 100) -> [VirtualPeer] {
        return createWithBehaviors(
            responsive: Int(Double(peerCount) * 0.5),
            slow: Int(Double(peerCount) * 0.2),
            unreliable: Int(Double(peerCount) * 0.15),
            intermittent: Int(Double(peerCount) * 0.1),
            malicious: Int(Double(peerCount) * 0.05)
        )
    }
}
