# Pulse — Peer-to-Peer Developer Networking

**iOS 26 | Liquid Glass Design | MultipeerConnectivity**

Discover and connect with nearby developers in real-time. No servers. No sign-ups. Just pure proximity-based networking.

---

## Features

- **Glass Field Radar** — Floating, morphing nodes show nearby devs
- **Liquid Glass UI** — iOS 26-native design with interactive glass effects
- **P2P Mesh** — MultipeerConnectivity for direct device-to-device communication
- **Zero PII** — No email, no phone, just a handle and tech stack
- **E2E Encrypted** — Messages encrypted with CryptoKit

---

## How to Run

### Requirements
- Xcode 26.0+
- iOS 26.0+ device or simulator
- macOS Tahoe (for development)

### Steps

1. **Open in Xcode**
   ```bash
   cd Pulse
   open Pulse.xcodeproj
   ```

2. **Set your Development Team**
   - Select the Pulse target
   - Go to Signing & Capabilities
   - Choose your team

3. **Run on Device**
   - MultipeerConnectivity requires physical devices (simulator won't discover peers)
   - Build and run on 2+ iOS 26 devices for full experience

4. **Test with Simulator**
   - Demo peers are pre-loaded for UI testing
   - Full networking requires real devices

---

## Project Structure

```
Pulse/
├── Pulse/
│   ├── PulseApp.swift              # App entry point
│   ├── ContentView.swift            # Root view (onboarding or radar)
│   ├── Views/
│   │   ├── RadarView.swift          # Main glass field with peer nodes
│   │   ├── PeerNode.swift           # Individual floating peer UI
│   │   ├── StatusToggleButton.swift # Morphing FAB for status
│   │   ├── ChatView.swift           # 1:1 messaging UI
│   │   └── OnboardingView.swift     # Handle + tech stack setup
│   ├── Models/
│   │   ├── PulsePeer.swift          # Peer data model
│   │   └── Message.swift            # Message + envelope models
│   ├── Managers/
│   │   └── MeshManager.swift        # MultipeerConnectivity wrapper
│   └── Info.plist                   # Background modes + permissions
└── Pulse.xcodeproj/
```

---

## iOS 26 Liquid Glass

This app fully embraces iOS 26's Liquid Glass design system:

- **`.glassEffect()`** — Applied to navigation elements (buttons, headers, input bars)
- **`GlassEffectContainer`** — Groups glass shapes for morphing transitions
- **`.interactive()`** — Touch-responsive glass with scaling and shimmer
- **Semantic Tinting** — Green (active), Yellow (flow state), Gray (idle)

**Key Rule:** Glass is for **navigation/controls**, not content. Messages stay clear.

---

## What's Next

- [ ] Add real RSSI-based distance estimation
- [ ] Implement E2E encryption (currently demo mode)
- [ ] Add Berkanan SDK for mesh relay
- [ ] Build Cursor/VS Code extension
- [ ] Add code snippet sharing with syntax highlighting
- [ ] Implement persistent chat history (Pro tier)

---

## Design Philosophy

> "The Radar isn't a list—it's a glass field where peers float, pulse, and morph based on proximity and availability."

This app demonstrates:
- iOS 26-native Liquid Glass design
- Peer-to-peer mesh networking
- Local-first architecture
- Zero-server philosophy

---

## License

MIT — Built with Claude Code

---

## Contact

Built by @jesse_codes
Powered by iOS 26 Liquid Glass
