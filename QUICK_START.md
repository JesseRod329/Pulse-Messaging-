# Pulse — Quick Start Guide

You now have a **complete, working iOS 26 app** with Liquid Glass design!

---

## What You Have

✅ **Full Xcode project** ready to build
✅ **Liquid Glass UI** with morphing, interactive glass effects
✅ **MultipeerConnectivity** for peer-to-peer discovery
✅ **5 main screens:**
  - OnboardingView (handle + tech stack setup)
  - RadarView (glass field with floating peer nodes)
  - PeerNode (individual developer bubbles)
  - StatusToggleButton (morphing FAB)
  - ChatView (1:1 messaging)

---

## How to Open & Run

### Step 1: Open in Xcode
```bash
cd ~/pulse/Pulse
open Pulse.xcodeproj
```

### Step 2: Set Your Team
1. Click on **Pulse** in the left sidebar (project navigator)
2. Select the **Pulse** target
3. Go to **Signing & Capabilities** tab
4. Under **Team**, select your Apple Developer account

### Step 3: Run It
- Press **⌘R** or click the Play button
- Choose an **iOS 26 simulator** or **real device**
- The app will launch with the onboarding screen

---

## What You'll See

### 1. Onboarding (First Launch)
- Enter a handle like `@jesse_codes`
- Pick your tech stack (Swift, Rust, Python, etc.)
- Tap "Start Discovering"

### 2. Radar View (Main Screen)
- You'll see **4 demo peers** floating in a glass field:
  - @jesse_codes (active, green, close)
  - @swift_sarah (active, green, medium distance)
  - @rust_dev (flow state, yellow, far)
  - @pythonista (idle, gray, very far)

- Nodes **pulse** if active
- Tap any node to open chat

### 3. Status Toggle (Bottom-Right)
- Tap the circular button to expand
- Choose your status:
  - 🟢 Active (open to chat)
  - 🟡 Flow State (visible but DND)
  - ⚪ Idle (away)
- Button morphs with Liquid Glass animation

### 4. Chat View
- Tap a peer node to open chat
- See demo messages
- Type and send (local only for now)

---

## Testing Real Peer Discovery

**Important:** Simulator cannot discover real peers. You need **2+ physical iOS 26 devices**.

### On Device:
1. Build and install on **Device 1**
2. Build and install on **Device 2**
3. Both devices will advertise via MultipeerConnectivity
4. They'll discover each other automatically
5. Tap to chat

---

## File Overview

Here's what each file does:

| File | Purpose |
|------|---------|
| `PulseApp.swift` | App entry point, starts MeshManager |
| `ContentView.swift` | Shows onboarding if first launch, else RadarView |
| `RadarView.swift` | Main screen with glass field of peer nodes |
| `PeerNode.swift` | Individual floating peer bubble |
| `StatusToggleButton.swift` | Morphing FAB for status selection |
| `ChatView.swift` | 1:1 messaging interface |
| `OnboardingView.swift` | Handle + tech stack setup |
| `MeshManager.swift` | MultipeerConnectivity wrapper, handles discovery |
| `PulsePeer.swift` | Data model for a peer |
| `Message.swift` | Data model for messages |
| `Info.plist` | Background modes for Bluetooth |

---

## Key iOS 26 Features Used

### Liquid Glass
- `.glassEffect()` — Applied to buttons, headers, input bars
- `.glassEffect(.regular.tint(.green).interactive())` — Tinted, touch-responsive glass
- `GlassEffectContainer` — Groups glass shapes for morphing
- `.glassEffectID()` — Enables smooth morphing transitions

### MultipeerConnectivity
- `MCNearbyServiceAdvertiser` — Broadcasts your presence
- `MCNearbyServiceBrowser` — Discovers nearby peers
- `MCSession` — Manages P2P connections

### SwiftUI 6
- `@MainActor` — Thread-safe state management
- `@Namespace` — Shared namespace for morphing
- `@EnvironmentObject` — Global mesh manager

---

## Next Steps

### Make It Yours
1. **Change Colors:** Edit tint colors in `RadarView.swift:49-55`
2. **Add More Tech:** Update `techOptions` in `OnboardingView.swift:14`
3. **Custom Icons:** Replace SF Symbols in `PeerNode.swift:57-68`

### Add Features
- **Distance Accuracy:** Use CoreBluetooth RSSI instead of random
- **Encryption:** Implement E2E with CryptoKit (see PULSE_iOS26_ARCHITECTURE.md)
- **Persistence:** Save chat history with SwiftData
- **Code Sharing:** Add syntax-highlighted code snippets

### Publish
- Create app icon (1024x1024px)
- Set up App Store Connect
- Submit for TestFlight beta
- Launch on App Store

---

## Troubleshooting

### "No peers found"
- Make sure you're on **physical devices** (not simulator)
- Both devices need Bluetooth and WiFi enabled
- Grant local network permissions when prompted

### "Build failed"
- Set your **Development Team** in Signing & Capabilities
- Make sure you have Xcode 26+ installed
- Target iOS 26.0+

### "Glass effects not showing"
- Ensure you're running on **iOS 26 simulator or device**
- Glass effects are iOS 26+ only

---

## Demo Mode

The app includes **demo peers** so you can test the UI without real devices:
- 4 pre-loaded peers with different statuses
- Demo chat messages
- All UI animations work

Remove demo peers in production by deleting:
```swift
// In MeshManager.swift:70-79
private func addDemoPeers() {
    // Delete this function
}
```

---

## Resources

- **Full Architecture:** See `PULSE_iOS26_ARCHITECTURE.md`
- **Apple Docs:** [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- **MultipeerConnectivity:** [Apple Docs](https://developer.apple.com/documentation/multipeerconnectivity)

---

**You're ready to build!** Open Xcode and hit run.

Questions? Check the architecture doc or README.
