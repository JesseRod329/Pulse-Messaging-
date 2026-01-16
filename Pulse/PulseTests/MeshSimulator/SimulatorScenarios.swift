//
//  SimulatorScenarios.swift
//  PulseTests
//
//  Pre-built simulation scenarios.
//

import Foundation

/// Available simulation scenarios
enum SimulatorScenario: String, CaseIterable {
    case coffeeShop = "coffee_shop"
    case conference = "conference"
    case hackathon = "hackathon"
    case commute = "commute"
    case office = "office"
    case stress = "stress"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .coffeeShop: return "Coffee Shop"
        case .conference: return "Conference"
        case .hackathon: return "Hackathon"
        case .commute: return "Commute"
        case .office: return "Office"
        case .stress: return "Stress Test"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .coffeeShop:
            return "Casual meetup with 5-15 developers, medium churn"
        case .conference:
            return "Dense networking event with 30-100 developers in clusters"
        case .hackathon:
            return "Teams of 3-6 in separate areas, low cross-team communication"
        case .commute:
            return "Brief encounters on public transit, high churn rate"
        case .office:
            return "Stable environment with star topology around common areas"
        case .stress:
            return "Maximum load test with 50-200 peers and high chaos"
        case .custom:
            return "Custom configuration"
        }
    }

    var suggestedPeerCount: ClosedRange<Int> {
        switch self {
        case .coffeeShop: return 5...15
        case .conference: return 30...100
        case .hackathon: return 20...40
        case .commute: return 10...20
        case .office: return 10...30
        case .stress: return 50...200
        case .custom: return 1...500
        }
    }

    var suggestedTopology: TopologyPreset {
        switch self {
        case .coffeeShop: return .mesh
        case .conference: return .random
        case .hackathon: return .partition
        case .commute: return .chain
        case .office: return .star
        case .stress: return .mesh
        case .custom: return .random
        }
    }

    var suggestedChaos: ChaosConfig {
        switch self {
        case .coffeeShop: return .low
        case .conference: return .moderate
        case .hackathon: return .low
        case .commute: return ChaosConfig(level: .moderate, churnRate: 0.2)
        case .office: return .none
        case .stress: return .high
        case .custom: return .moderate
        }
    }

    var suggestedDuration: TimeInterval {
        switch self {
        case .coffeeShop: return 60
        case .conference: return 180
        case .hackathon: return 120
        case .commute: return 30
        case .office: return 300
        case .stress: return 120
        case .custom: return 60
        }
    }

    var suggestedMessageRate: Double {  // Messages per second
        switch self {
        case .coffeeShop: return 5
        case .conference: return 20
        case .hackathon: return 10
        case .commute: return 3
        case .office: return 8
        case .stress: return 50
        case .custom: return 10
        }
    }
}

// MARK: - Scenario Builder

@MainActor
struct ScenarioBuilder {

    /// Build a complete simulation configuration from a scenario
    static func build(_ scenario: SimulatorScenario, peerCount: Int? = nil) -> SimulatorConfig {
        let count = peerCount ?? scenario.suggestedPeerCount.randomElement()!

        return SimulatorConfig(
            peerCount: count,
            duration: scenario.suggestedDuration,
            scenario: scenario,
            chaos: scenario.suggestedChaos,
            messageRate: scenario.suggestedMessageRate,
            tracingEnabled: true
        )
    }

    /// Create peers for a scenario
    static func createPeers(for scenario: SimulatorScenario) -> [VirtualPeer] {
        switch scenario {
        case .coffeeShop:
            return VirtualPeerFactory.coffeeShopScenario()
        case .conference:
            return VirtualPeerFactory.conferenceScenario()
        case .hackathon:
            return VirtualPeerFactory.hackathonScenario()
        case .commute:
            return VirtualPeerFactory.commuteScenario()
        case .office:
            return VirtualPeerFactory.officeScenario()
        case .stress:
            return VirtualPeerFactory.stressScenario()
        case .custom:
            return VirtualPeerFactory.createPeers(count: 20)
        }
    }

    /// Apply topology for a scenario
    static func applyTopology(
        _ topology: TopologyController,
        for scenario: SimulatorScenario
    ) {
        topology.apply(preset: scenario.suggestedTopology)
    }
}

// MARK: - Quick Scenarios

extension SimulatorConfig {

    /// Quick 30-second test with 10 peers
    @MainActor
    static func quick(_ scenario: SimulatorScenario = .coffeeShop) -> SimulatorConfig {
        var config = ScenarioBuilder.build(scenario, peerCount: 10)
        config.duration = 30
        config.chaos = .low
        return config
    }

    /// Standard 60-second test
    @MainActor
    static func standard(_ scenario: SimulatorScenario = .coffeeShop) -> SimulatorConfig {
        ScenarioBuilder.build(scenario)
    }

    /// Extended 5-minute stress test
    @MainActor
    static func extended(_ scenario: SimulatorScenario = .stress) -> SimulatorConfig {
        var config = ScenarioBuilder.build(scenario, peerCount: 100)
        config.duration = 300
        config.chaos = .high
        return config
    }

    /// Chaos-focused test
    static func chaosTest(level: ChaosLevel = .extreme) -> SimulatorConfig {
        SimulatorConfig(
            peerCount: 30,
            duration: 120,
            scenario: .stress,
            chaos: ChaosConfig(
                level: level,
                batteryDeaths: level == .extreme ? 5 : 2,
                partitionEvents: level == .extreme ? 3 : 1,
                signalDegradation: level == .extreme
            ),
            messageRate: 20,
            tracingEnabled: true
        )
    }

    /// Partition recovery test
    static func partitionTest() -> SimulatorConfig {
        SimulatorConfig(
            peerCount: 20,
            duration: 60,
            scenario: .hackathon,
            chaos: ChaosConfig(level: .low, partitionEvents: 2),
            messageRate: 10,
            tracingEnabled: true
        )
    }

    /// High throughput test
    static func throughputTest() -> SimulatorConfig {
        SimulatorConfig(
            peerCount: 50,
            duration: 60,
            scenario: .conference,
            chaos: .none,
            messageRate: 100,
            tracingEnabled: true
        )
    }
}
