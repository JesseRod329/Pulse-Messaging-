# Pulse Messaging

Pulse is a peer-to-peer iOS messaging app that explores local discovery and resilient communication without relying on centralized servers. The project focuses on privacy, reliability, and a clean, minimal user experience.

## Purpose

Build a fast, local-first messenger that can operate in constrained networks while keeping user data under user control.

## Journey

This repository captures the full build of Pulse: from architecture exploration to security audits and reliability improvements. It documents the trade-offs, the fixes we made, and the practical lessons learned while getting a real device-first experience to feel dependable.

If you want the deeper technical walkthroughs, see:
- `PULSE_iOS26_ARCHITECTURE.md`
- `PULSE_AUDIT_REPORT.md`
- `IMPROVEMENTS_SUMMARY.md`

## Features

- Nearby peer discovery and mesh-style messaging
- End-to-end encryption with message signing and verification
- Resilient delivery with acknowledgements and deduplication
- Privacy controls for link previews and discovery profile sharing

## Getting Started

1. Open `Pulse/Pulse.xcodeproj` in Xcode.
2. Select an iOS 26 simulator (or device) and run the `Pulse` scheme.
3. Use `PulseTests` to run the test suite.

## Notes

- The test suite expects an iOS 26 simulator; adjust the destination as needed.
- This repo intentionally avoids any mock data in dev/prod.
