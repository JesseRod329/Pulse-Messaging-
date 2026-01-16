#if !canImport(XCTest)
//
//  RunSimulator.swift
//  Quick mesh simulator demo - runs without Xcode test target
//

import Foundation

// Since we can't import the full Pulse module in a script,
// this is a standalone demo of the simulator concepts

print("═══════════════════════════════════════════════════════")
print("         MESH SIMULATOR - Standalone Demo              ")
print("═══════════════════════════════════════════════════════")
print("")

// Simulated peer
struct DemoPeer {
    let id: String
    let handle: String
    var connections: Set<String> = []

    mutating func connect(to peerId: String) {
        connections.insert(peerId)
    }
}

// Create demo peers
var peers: [String: DemoPeer] = [:]
let handles = ["swift_ninja", "rust_wizard", "py_guru", "go_master", "js_pro"]

print("Creating \(handles.count) virtual peers...")
for handle in handles {
    let id = UUID().uuidString
    peers[id] = DemoPeer(id: id, handle: handle)
}

// Create mesh topology
print("Applying mesh topology...")
let peerIds = Array(peers.keys)
var edgeCount = 0
for i in 0..<peerIds.count {
    for j in (i+1)..<peerIds.count {
        peers[peerIds[i]]?.connect(to: peerIds[j])
        peers[peerIds[j]]?.connect(to: peerIds[i])
        edgeCount += 1
    }
}

print("Created \(edgeCount) connections")
print("")

// Simulate message routing
print("Simulating message routing...")
var delivered = 0
var dropped = 0
let messageCount = 50

for _ in 0..<messageCount {
    let sender = peerIds.randomElement()!
    var recipient = peerIds.randomElement()!
    while recipient == sender {
        recipient = peerIds.randomElement()!
    }

    // Simulate 95% delivery rate
    if Double.random(in: 0...1) < 0.95 {
        delivered += 1
    } else {
        dropped += 1
    }
}

let deliveryRate = Double(delivered) / Double(messageCount) * 100

print("")
print("═══════════════════════════════════════════════════════")
print("                    RESULTS                            ")
print("═══════════════════════════════════════════════════════")
print("")
print("Peers:           \(peers.count)")
print("Connections:     \(edgeCount)")
print("Messages Sent:   \(messageCount)")
print("Delivered:       \(delivered)")
print("Dropped:         \(dropped)")
print("Delivery Rate:   \(String(format: "%.1f", deliveryRate))%")
print("")
print("═══════════════════════════════════════════════════════")
print("To run full simulator with all features:")
print("1. Add PulseTests target in Xcode")
print("2. Or use: /mesh-simulator in Claude Code")
print("═══════════════════════════════════════════════════════")
#endif