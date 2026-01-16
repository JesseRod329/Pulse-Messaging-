## Pulse iOS App End-to-End Audit

Date: 2026-01-14
Scope: onboarding → discovery → chat → persistence → mesh/nostr → settings

### Executive Summary
- Critical gaps in message authenticity and peer verification allow impersonation.
- Nostr transport is effectively non-functional due to unsigned events.
- Reliability is impacted by broken acknowledgment handling and settings not applied at runtime.
- Data retention and privacy need tightening (plaintext at rest, broadcast metadata, link preview fetches).

### Findings (ordered by severity)

#### Critical
- No message authenticity or peer verification. Sessions auto-accept and messages are only encrypted, not signed or bound to a verified identity. This allows impersonation (any peer can claim a handle and key).
  - Evidence: `MeshManager` auto-accepts invitations; `SignedMessageEnvelope` exists but is unused.
- Nostr transport publishes unsigned events. Most relays will reject these, and spoofing is possible if any relay accepts them.
  - Evidence: `NostrTransport` comment indicates unsigned publish.

#### High
- Acknowledgment flow is broken; retries never resolve. `messageAck` packets are generated but decoded as message envelopes, so pending acks never clear.
- Settings toggles (`meshEnabled`, `nostrEnabled`, `maxHops`) do not affect runtime transport config. UI writes to `UserDefaults`, but `UnifiedTransportManager.config` is never updated.
- “Clear All Data” does not remove SwiftData chat history. It clears `UserDefaults`, keychain, and files, but leaves the SwiftData store intact.
- Sent messages are stored in plaintext at rest. This conflicts with the “E2E encrypted” positioning and is a data-at-rest risk.

#### Medium
- Discovery advertising broadcasts handle, tech stack, public key, avatar hash, and place. BLE advertising uses a stable `myPeerID` as local name, increasing trackability.
- Link previews fetch arbitrary URLs in the client, potentially leaking IP and metadata without explicit consent.

#### Low
- Tests are strong for mesh simulation and crypto, but there is no coverage for persistence, acknowledgments, transport toggles, or settings-runtime integration.

### Recommended Remediation
- Implement message signing/verification and bind handle ↔ key (use `SignedMessageEnvelope`, verify on receipt).
- Fix acknowledgment handling for `PacketType.messageAck` and clear pending acks.
- Wire settings toggles to `UnifiedTransportManager.config` and apply immediately.
- Add a “Clear All Data” path that deletes SwiftData stores and related files.
- Decide on a policy for sent-message plaintext at rest (encrypt at rest or remove plaintext storage).
- Add explicit user consent for link previews (or defer fetch until user taps).

### Files Reviewed (non-exhaustive)
- `Pulse/Pulse/Managers/MeshManager.swift`
- `Pulse/Pulse/Managers/ChatManager.swift`
- `Pulse/Pulse/Managers/IdentityManager.swift`
- `Pulse/Pulse/Managers/PersistenceManager.swift`
- `Pulse/Pulse/Managers/KeychainManager.swift`
- `Pulse/Pulse/Models/PulseIdentity.swift`
- `Pulse/Pulse/Models/Message.swift`
- `Pulse/Pulse/Models/PersistedMessage.swift`
- `Pulse/Pulse/Networking/UnifiedTransportManager.swift`
- `Pulse/Pulse/Networking/NostrTransport.swift`
- `Pulse/Pulse/Networking/MessageRouter.swift`
- `Pulse/Pulse/Networking/TransportProtocol.swift`
- `Pulse/Pulse/Views/SettingsView.swift`
