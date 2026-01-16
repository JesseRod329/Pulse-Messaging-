//
//  BLEAdvertiser.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import CoreBluetooth

@MainActor
final class BLEAdvertiser: NSObject, ObservableObject {
    static let shared = BLEAdvertiser()

    @Published var isAdvertising = false

    private nonisolated(unsafe) var peripheralManager: CBPeripheralManager!

    // Same service UUID as RSSIManager for peer correlation
    private let pulseServiceUUID = CBUUID(string: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E")

    private let powerManager = PowerManager.shared

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            print("Peripheral manager not ready, state: \(peripheralManager.state.rawValue)")
            return
        }

        // Get the user's peer ID to use as local name
        let localName = UserDefaults.standard.string(forKey: "myPeerID") ?? "Pulse"

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [pulseServiceUUID],
            CBAdvertisementDataLocalNameKey: localName
        ]

        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
    }

    /// Adjust advertising based on power state
    func adjustForPowerState() {
        if powerManager.shouldStopDiscovery {
            stopAdvertising()
        } else if powerManager.isPowerConstrained && isAdvertising {
            // In power-constrained mode, we can still advertise but
            // it's handled by iOS automatically reducing frequency
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEAdvertiser: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                print("Peripheral manager powered on")
                // Auto-start advertising when ready
                startAdvertising()
            case .poweredOff:
                print("Peripheral manager powered off")
                isAdvertising = false
            case .unauthorized:
                print("Peripheral manager unauthorized")
            case .unsupported:
                print("Peripheral manager unsupported")
            case .resetting:
                print("Peripheral manager resetting")
            case .unknown:
                print("Peripheral manager state unknown")
            @unknown default:
                print("Unknown peripheral manager state")
            }
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("Failed to start advertising: \(error)")
                isAdvertising = false
            } else {
                print("Started BLE advertising")
            }
        }
    }
}
