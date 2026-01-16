//
//  RSSIManager.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
final class RSSIManager: NSObject, ObservableObject {
    static let shared = RSSIManager()

    @Published var peerDistances: [String: Double] = [:]
    @Published var isScanning = false

    private nonisolated(unsafe) var centralManager: CBCentralManager!
    private var distanceUpdateTimer: Timer?

    // Pulse service UUID - used to identify Pulse peers via BLE
    private let pulseServiceUUID = CBUUID(string: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E")

    // Path-loss model parameters for RSSI to distance conversion
    // TxPower: RSSI at 1 meter (calibrated per device, -59 is typical)
    // PathLossExponent: 2.0 = free space, 2.5-4.0 = indoors with obstacles
    private let txPower: Double = -59
    private let pathLossExponent: Double = 2.5

    private let powerManager = PowerManager.shared

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready, state: \(centralManager.state.rawValue)")
            return
        }

        // Scan for Pulse service, allow duplicates for RSSI updates
        centralManager.scanForPeripherals(
            withServices: [pulseServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true

        // Start periodic distance update timer
        startDistanceUpdates()
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        distanceUpdateTimer?.invalidate()
        distanceUpdateTimer = nil
    }

    private func startDistanceUpdates() {
        // Distance updates happen in real-time via didDiscover callback
        // This timer is no longer needed but kept for potential cleanup tasks
        distanceUpdateTimer?.invalidate()
        distanceUpdateTimer = nil
    }

    /// Convert RSSI to distance in meters using path-loss model
    /// Formula: d = 10^((TxPower - RSSI) / (10 * n))
    private func rssiToDistance(_ rssi: Int) -> Double {
        let exponent = (txPower - Double(rssi)) / (10 * pathLossExponent)
        let distance = pow(10, exponent)

        // Clamp to reasonable range (1m - 100m)
        return min(max(distance, 1.0), 100.0)
    }

    /// Get distance for a peer by name, with fallback
    func distance(for peerName: String) -> Double {
        return peerDistances[peerName] ?? 50.0 // Default to medium distance
    }

    /// Adjust scanning based on power state
    func adjustForPowerState() {
        if powerManager.shouldStopDiscovery {
            stopScanning()
        } else if powerManager.isPowerConstrained {
            // Reduce scan frequency
            stopScanning()
            // Scan briefly every 15 seconds
            Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.startScanning()
                    try? await Task.sleep(for: .seconds(5))
                    self?.stopScanning()
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension RSSIManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                print("Bluetooth powered on")
                // Auto-start scanning when ready
                startScanning()
            case .poweredOff:
                print("Bluetooth powered off")
                isScanning = false
            case .unauthorized:
                print("Bluetooth unauthorized")
            case .unsupported:
                print("Bluetooth unsupported")
            case .resetting:
                print("Bluetooth resetting")
            case .unknown:
                print("Bluetooth state unknown")
            @unknown default:
                print("Unknown Bluetooth state")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Capture values before Task to avoid data races
        let name = peripheral.name ?? peripheral.identifier.uuidString
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            // Update distance immediately (don't store peripheral reference)
            peerDistances[name] = rssiToDistance(rssiValue)
        }
    }
}
