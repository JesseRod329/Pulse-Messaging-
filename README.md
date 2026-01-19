# Pulse

**Decentralized messaging for iOS with Lightning payments.**

A high-performance iOS messaging engine written 100% in **Swift**. Pulse facilitates peer-to-peer, decentralized communication without reliance on centralized servers. Built for the 2026 iOS ecosystem with secure key management, mesh networking, Lightning zaps, and real-time data streaming via Nostr relays.

> No servers. No silos. Just Pulse.

---

## 💡 The Vision

Pulse is inspired by **Bitchat** and the broader **Nostr** ecosystem—protocols championed by Jack Dorsey and the open-source community. The goal is to move away from "platforms" and toward "protocols," ensuring that your identity and your conversations remain yours, regardless of who owns the network.

This isn't just an app; it's a step toward sovereign communication—private, censorship-resistant, and entirely user-owned.

---

## ✨ Features

### Core Messaging
| Category | What Pulse Does |
|----------|-----------------|
| **Mesh Discovery** | Nearby peer detection via Bluetooth LE and MultipeerConnectivity |
| **End-to-End Encryption** | All messages encrypted with Curve25519 key exchange |
| **Message Signing** | Ed25519 signatures verify sender authenticity |
| **Resilient Delivery** | Acknowledgements, deduplication, and multi-hop routing |
| **Privacy Controls** | Toggles for link previews, discovery profile sharing, and data retention |
| **Offline-First** | Local SwiftData persistence; works without internet |

### Lightning Network (NIP-57)
| Category | What Pulse Does |
|----------|-----------------|
| **Zap Requests** | Send Bitcoin tips via Lightning to any Nostr user |
| **Zap Receipts** | Receive and display incoming zaps on messages |
| **Lightning Addresses** | Support for `user@domain.com` style addresses |
| **Wallet Integration** | Opens Zeus, Muun, Phoenix, BlueWallet, or any BOLT11 wallet |
| **BOLT11 Validation** | Full invoice parsing and security verification |

### Nostr Protocol
| Category | What Pulse Does |
|----------|-----------------|
| **Relay Connections** | Connect to multiple Nostr relays for global reach |
| **Event Signing** | secp256k1 Schnorr signatures for Nostr events |
| **Location Channels** | Geohash-based public channels for local discovery |
| **Profile Metadata** | NIP-01 profile publishing with Lightning address support |
| **NIP-42 Auth** | Relay authentication challenge/response |

### Security Hardening
| Category | What Pulse Does |
|----------|-----------------|
| **Invoice Security** | Three-way amount verification (UI → Zap Request → Invoice) |
| **Signature Validation** | All Nostr events cryptographically verified |
| **Rate Limiting** | DoS protection for relay events |
| **Certificate Pinning** | TLS validation for all network connections |
| **Clipboard Protection** | Auto-clear sensitive data after 30 seconds |
| **Privacy UI** | `.privacySensitive()` modifiers hide data in app switcher |
| **Wallet URI Sanitization** | Prevents injection attacks in external wallet calls |
| **Secure Keychain** | Keys stored with `WhenUnlockedThisDeviceOnly` access control |

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
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                            │
│   ChatView │ ProfileView │ SettingsView │ ZapButton │ Radar    │
├─────────────────────────────────────────────────────────────────┤
│  ChatManager  │  ZapManager  │  MeshManager  │  IdentityManager │
├─────────────────────────────────────────────────────────────────┤
│              UnifiedTransportManager (Mesh + Nostr)             │
├─────────────────────────────────────────────────────────────────┤
│  MultipeerConnectivity  │  BLE Advertiser  │  NostrTransport    │
├─────────────────────────────────────────────────────────────────┤
│  LNURLService  │  Bolt11Validator  │  SecureNetworkSession      │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

- **Managers/** – Business logic (chat, mesh, identity, zaps, persistence)
- **Networking/** – Transport protocols, Nostr relay connections, LNURL/BOLT11 handling
- **Models/** – Data types (Message, PulsePeer, NostrIdentity, Zap)
- **Views/** – SwiftUI interface with Liquid Glass design
- **Utilities/** – Clipboard security, debug logging, avatar management

### Security Components

| Component | Purpose |
|-----------|---------|
| `Bolt11Validator` | Parses and validates Lightning invoices |
| `NostrEventValidator` | Validates event signatures and format |
| `ZapSecurityGuard` | Three-way amount verification |
| `WalletURISanitizer` | Sanitizes wallet deep links |
| `SecureNetworkSession` | TLS certificate validation |
| `ClipboardManager` | Auto-clears sensitive clipboard data |
| `RateLimiter` | Prevents event flooding |

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

### Lightning Wallet Setup

To send zaps, you'll need a Lightning wallet installed:
- **Zeus** (recommended) - Full node control
- **Phoenix** - Simple and automatic
- **Muun** - Bitcoin + Lightning
- **BlueWallet** - Multi-wallet support

---

## 🧪 Tests

```bash
xcodebuild -project Pulse.xcodeproj -scheme PulseTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 17' \
  test
```

### Test Suite

| Test File | Coverage |
|-----------|----------|
| `PulseIdentityTests` | Identity creation, encryption, signing |
| `Bolt11ValidatorTests` | Invoice parsing, malicious input rejection |
| `Bolt11ParserTests` | BOLT11 field extraction |
| `NostrNormalizationTests` | Deterministic JSON for NIP-57 |
| `SecurityHardeningTests` | Rate limiting, URI sanitization |
| `ProductionSecurityTests` | End-to-end security scenarios |
| `MeshSimulatorTests` | Virtual peer network testing |

---

## 📚 Documentation

| Doc | Description |
|-----|-------------|
| [PULSE_iOS26_ARCHITECTURE.md](PULSE_iOS26_ARCHITECTURE.md) | Technical deep-dive into the system design |
| [PULSE_AUDIT_REPORT.md](PULSE_AUDIT_REPORT.md) | Security audit findings and remediations |
| [BITCOIN_PLAN.md](BITCOIN_PLAN.md) | Lightning integration security hardening plan |
| [IMPROVEMENTS_SUMMARY.md](IMPROVEMENTS_SUMMARY.md) | Changelog of major improvements |
| [QUICK_START.md](QUICK_START.md) | Fast-track setup guide |

---

## 🔐 Security Model

### Threat Mitigations

| Threat | Mitigation |
|--------|------------|
| Invoice Swapping | BOLT11 amount verification against zap request |
| Fake Zap Receipts | Schnorr signature validation on all receipts |
| Wallet URI Injection | Strict scheme whitelist + character filtering |
| Relay Event Flooding | Fixed-window rate limiter (60 events/sec) |
| MITM Attacks | Certificate validation on all HTTPS/WSS connections |
| Clipboard Sniffing | Auto-clear after 30s + clear on background |
| Key Extraction | Keychain with biometric/device-only access |

### Cryptographic Primitives

- **Encryption**: Curve25519 (X25519) key exchange + ChaCha20-Poly1305
- **Signing**: Ed25519 for mesh messages, secp256k1 Schnorr for Nostr
- **Hashing**: SHA-256 for event IDs and description hashes
- **Key Storage**: iOS Keychain with `.whenUnlockedThisDeviceOnly`

---

## 🙏 Inspiration & Credits

Pulse draws heavily from:
- **[Nostr](https://nostr.com/)** – The decentralized social protocol
- **Bitchat** – Jack Dorsey's vision for open, censorship-resistant messaging
- **[secp256k1](https://github.com/bitcoin-core/secp256k1)** – Elliptic curve cryptography
- **[NIP-57](https://github.com/nostr-protocol/nips/blob/master/57.md)** – Lightning Zaps specification
- **[BOLT11](https://github.com/lightning/bolts/blob/master/11-payment-encoding.md)** – Lightning invoice format

This project exists because open protocols matter.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Built with ❤️ by <a href="https://github.com/JesseRod329">Jesse Rodriguez</a></strong>
</p>
