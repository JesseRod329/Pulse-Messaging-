# Pulse

**Decentralized messaging for iOS.**

A high-performance iOS messaging engine written 100% in **Swift**. Pulse facilitates peer-to-peer, decentralized communication without reliance on centralized servers. Built for the 2026 iOS ecosystem with secure key management, mesh networking, and real-time data streaming via open relays.

> No servers. No silos. Just Pulse.

---

## 💡 The Vision

Pulse is inspired by **Bitchat** and the broader **Nostr** ecosystem—protocols championed by Jack Dorsey and the open-source community. The goal is to move away from "platforms" and toward "protocols," ensuring that your identity and your conversations remain yours, regardless of who owns the network.

This isn't just an app; it's a step toward sovereign communication—private, censorship-resistant, and entirely user-owned.

---

## ✨ Features

| Category | What Pulse Does |
|----------|-----------------|
| **Mesh Discovery** | Nearby peer detection via Bluetooth LE and MultipeerConnectivity |
| **End-to-End Encryption** | All messages encrypted with Curve25519 key exchange |
| **Message Signing** | Ed25519 signatures verify sender authenticity |
| **Resilient Delivery** | Acknowledgements, deduplication, and multi-hop routing |
| **Privacy Controls** | Toggles for link previews, discovery profile sharing, and data retention |
| **Offline-First** | Local SwiftData persistence; works without internet |
| **Open Protocol Ready** | Nostr transport layer for relay-based messaging (WIP) |

---

## 📸 Screenshots

![Pulse screenshot 1](media/screenshot-1.png)
![Pulse screenshot 2](media/screenshot-2.png)
![Pulse screenshot 3](media/screenshot-3.png)
![Pulse screenshot 4](media/screenshot-4.png)
![Pulse screenshot 5](media/screenshot-5.png)

## 🎥 Walkthrough

[Watch the walkthrough video](media/walkthrough.mp4)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      SwiftUI Views                      │
├─────────────────────────────────────────────────────────┤
│  ChatManager  │  MeshManager  │  IdentityManager        │
├─────────────────────────────────────────────────────────┤
│         UnifiedTransportManager (Mesh + Nostr)          │
├─────────────────────────────────────────────────────────┤
│  MultipeerConnectivity  │  BLE Advertiser  │  WebSocket │
└─────────────────────────────────────────────────────────┘
```

- **Managers/** – Business logic (chat, mesh, identity, persistence)
- **Networking/** – Transport protocols, routing, deduplication
- **Models/** – Data types (Message, PulsePeer, PulseIdentity)
- **Views/** – SwiftUI interface with Liquid Glass design

---

## 🚀 Getting Started

1. Clone the repo
2. Open `Pulse/Pulse.xcodeproj` in Xcode 26+
3. Select an iOS 26 simulator or device
4. Run the `Pulse` scheme

```bash
git clone https://github.com/JesseRod329/Pulse-Messaging-.git
cd Pulse-Messaging-/Pulse
open Pulse.xcodeproj
```

---

## 🧪 Tests

```bash
xcodebuild -project Pulse.xcodeproj -scheme PulseTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' \
  test
```

The test suite includes:
- Identity/crypto tests
- Mesh simulator with virtual peers
- Chaos testing for network reliability

---

## 📚 Documentation

| Doc | Description |
|-----|-------------|
| [PULSE_iOS26_ARCHITECTURE.md](PULSE_iOS26_ARCHITECTURE.md) | Technical deep-dive into the system design |
| [PULSE_AUDIT_REPORT.md](PULSE_AUDIT_REPORT.md) | Security audit findings and remediations |
| [IMPROVEMENTS_SUMMARY.md](IMPROVEMENTS_SUMMARY.md) | Changelog of major improvements |
| [QUICK_START.md](QUICK_START.md) | Fast-track setup guide |

---

## 🙏 Inspiration & Credits

Pulse draws heavily from:
- **[Nostr](https://nostr.com/)** – The decentralized social protocol
- **Bitchat** – Jack Dorsey's vision for open, censorship-resistant messaging
- **[secp256k1](https://github.com/bitcoin-core/secp256k1)** – Elliptic curve cryptography

This project exists because open protocols matter.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Built with ❤️ by <a href="https://github.com/JesseRod329">Jesse Rodriguez</a></strong>
</p>
