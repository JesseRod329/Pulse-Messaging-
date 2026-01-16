# Pulse Privacy Policy

**Last Updated: January 2026**

## Overview

Pulse is a peer-to-peer messaging app designed with privacy as a core principle. We do not collect, store, or transmit your personal data to any servers.

## Data Collection

**We do not collect any personal data.**

Pulse operates entirely on a peer-to-peer basis using:
- Bluetooth Low Energy (BLE) for proximity detection
- MultipeerConnectivity for local mesh networking
- Optional Nostr relay connections (user-initiated only)

### What Pulse Stores Locally

All data is stored exclusively on your device:

1. **Profile Information**
   - Your chosen handle (username)
   - Selected tech stack preferences
   - Optional profile photo
   - Status settings

2. **Messages**
   - All messages are stored locally on your device
   - Messages are end-to-end encrypted using Curve25519 + AES-GCM
   - Only you and your conversation partner can read messages

3. **Cryptographic Identity**
   - A unique cryptographic key pair is generated on your device
   - Private keys never leave your device
   - Keys are stored securely in iOS Keychain

### What Pulse Does NOT Collect

- No analytics or telemetry data
- No location data sent to servers (geohash calculations are local-only)
- No contact information
- No advertising identifiers
- No device fingerprinting
- No crash reports or diagnostics sent externally

## Device Permissions

Pulse requests the following permissions:

### Bluetooth
- **Purpose**: Discover nearby developers and measure proximity
- **Usage**: BLE advertising and scanning for peer discovery
- **Data Sent**: Only your handle and status (broadcast locally, not to servers)

### Microphone
- **Purpose**: Record voice notes
- **Usage**: Voice messages are encrypted before being sent to peers
- **Data Sent**: Encrypted voice data transmitted directly to chat peers only

### Local Network
- **Purpose**: Enable mesh networking for peer-to-peer messaging
- **Usage**: MultipeerConnectivity for local WiFi/Bluetooth communication
- **Data Sent**: Messages are encrypted and sent directly between devices

## End-to-End Encryption

All communications in Pulse are end-to-end encrypted:

- **Key Exchange**: Curve25519 elliptic curve Diffie-Hellman
- **Message Encryption**: AES-256-GCM authenticated encryption
- **Key Storage**: iOS Keychain (hardware-backed on supported devices)

This means:
- Messages can only be decrypted by intended recipients
- No one (including us) can read your messages
- Even if messages are intercepted, they cannot be decrypted

## Data Sharing

**We do not share any data with third parties.**

- No data is sold
- No data is shared with advertisers
- No data is shared with analytics providers
- No data is transmitted to our servers (we have none)

## Optional Features

### Nostr Relay (Optional)
If you enable Nostr relay support:
- Messages may be routed through public Nostr relays
- Only encrypted message content is transmitted
- Relay operators cannot decrypt your messages
- You can disable this feature at any time

### Location Channels (Optional)
If you enable location channels:
- Geohash is calculated locally from your location
- Only the geohash (not precise coordinates) is shared with nearby peers
- No location data is sent to servers
- You can disable this feature at any time

## Data Retention

- All data remains on your device until you delete it
- Clearing app data removes all local storage
- Uninstalling the app removes all associated data
- We retain no data about you

## Children's Privacy

Pulse is intended for users 13 years of age and older. We do not knowingly collect information from children under 13.

## Changes to This Policy

We may update this privacy policy from time to time. We will notify you of any changes by updating the "Last Updated" date.

## Contact

If you have questions about this privacy policy, please contact us at:

- Email: privacy@pulse-mesh.app
- GitHub: https://github.com/pulse-mesh/pulse-ios

## Your Rights

Since we don't collect your data, there's nothing to:
- Request access to
- Request deletion of
- Request correction of
- Export

Your data is yours, stored on your device, under your control.

---

**Summary**: Pulse is designed to give you private, encrypted communication without data collection. Your messages stay between you and your contacts, protected by strong encryption, with no servers in between.
