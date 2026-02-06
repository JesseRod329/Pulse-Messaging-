# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pulse is an iOS decentralized messaging app written in Swift. It uses BLE/MultipeerConnectivity for local mesh networking and Nostr relays for global reach. No servers — all peer-to-peer.

## Build & Run

The Xcode project lives at `Pulse/Pulse.xcodeproj`. Open it in Xcode 26+.

```bash
# Build for simulator
xcodebuild -project Pulse/Pulse.xcodeproj -scheme Pulse \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' \
  build

# Run all tests
xcodebuild -project Pulse/Pulse.xcodeproj -scheme PulseTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' \
  test

# Run a single test class
xcodebuild -project Pulse/Pulse.xcodeproj -scheme PulseTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' \
  -only-testing:PulseTests/NostrEventValidatorTests \
  test
```

Deployment target: iOS 26.0 for the app, iOS 17.4 for test targets. Swift 5.0 for the app target.

## Architecture

All source is under `Pulse/Pulse/`. The app uses `@MainActor` isolation throughout managers and networking.

### Dual-Transport System

`UnifiedTransportManager` coordinates two transport paths:
- **Mesh** (`MeshManager` + `BLEAdvertiser`): Local peer discovery via MultipeerConnectivity and CoreBluetooth. Uses `MCSession` with service type `_pulse-mesh._tcp`.
- **Nostr** (`NostrTransport`): WebSocket connections to Nostr relays for global messaging and location channels.

Both implement `TransportProtocol`. Messages go through `MessageRouter` (multi-hop routing, max 7 hops) and `MessageDeduplicationService` before delivery.

### Key Singletons

Most managers use `static let shared` singletons:
- `ChatManager` — conversation state, link previews, message handling
- `MeshManager` — MultipeerConnectivity session, peer discovery (this one is `@StateObject` in `PulseApp`, injected as `@EnvironmentObject`)
- `IdentityManager` + `NostrIdentityManager` — key generation/storage, Nostr profile
- `PersistenceManager` — SwiftData container (`PersistedMessage`, `PersistedConversation`, `PersistedGroup`)
- `KeychainManager` — secure key storage with `.whenUnlockedThisDeviceOnly`

### Security Stack

`NostrEventValidator` verifies secp256k1 Schnorr signatures. `RateLimiter` prevents relay event flooding (60 events/sec). `SecureNetworkSession` enforces TLS certificate validation. `ClipboardManager` auto-clears sensitive data after 30 seconds.

### Data Layer

SwiftData models prefixed with `Persisted*` (`PersistedMessage`, `PersistedConversation`, `PersistedGroup`). In-memory models (`Message`, `PulsePeer`, `Group`) are used in the view layer. `PersistenceManager.shared.container` is injected via `.modelContainer()` at the app root.

### Crypto

- Curve25519 (X25519) key exchange + ChaCha20-Poly1305 for mesh message encryption
- Ed25519 for mesh message signing
- secp256k1 Schnorr for Nostr event signing
- All via Apple CryptoKit except secp256k1

## Test Suite

Tests are in `Pulse/PulseTests/`. Notable test infrastructure:
- `MeshSimulator/` — virtual peer network with `ChaosEngine`, `TopologyController`, `VirtualPeer` for simulating mesh conditions
- Security tests cover rate limiting, Nostr event validation, and sensitive string scrubbing

## Bundle ID & Background Modes

Bundle ID: `com.jesse.pulse-mesh`. Background task ID: `com.jesse.pulse-mesh.discovery`. Bluetooth central/peripheral background modes enabled.
