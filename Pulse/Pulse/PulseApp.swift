//
//  PulseApp.swift
//  Pulse
//
//  Created on December 31, 2025.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct PulseApp: App {
    @StateObject private var meshManager = MeshManager()
    private let persistenceManager = PersistenceManager.shared
    private let voiceNoteManager = VoiceNoteManager.shared

    init() {
        // SECURITY: Register ClipboardManager for app lifecycle notifications
        // This ensures clipboard is cleared when app enters background
        Task { @MainActor in
            ClipboardManager.shared.registerForAppLifecycleNotifications()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meshManager)
                .modelContainer(persistenceManager.container)
                .onAppear {
                    // Clean up orphaned audio files on launch
                    voiceNoteManager.cleanupOrphanedFiles()

                    // Start advertising when app launches
                    meshManager.startAdvertising()

                    // Schedule background peer discovery
                    scheduleBackgroundDiscovery()
                }
                .onDisappear {
                    meshManager.stopAdvertising()
                }
        }
    }

    // MARK: - Background Tasks

    private func scheduleBackgroundDiscovery() {
        // Register background task request types (must match Info.plist)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jesse.pulse-mesh.discovery",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundDiscoveryTask(processingTask)
        }

        // Schedule the background discovery task
        let request = BGProcessingTaskRequest(identifier: "com.jesse.pulse-mesh.discovery")
        request.requiresNetworkConnectivity = false // Bluetooth doesn't need network
        request.requiresExternalPower = false // Can run on battery

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background peer discovery scheduled")
        } catch {
            print("❌ Failed to schedule background discovery: \(error)")
        }
    }

    private func handleBackgroundDiscoveryTask(_ task: BGTask) {
        // Set expiration handler (OS will terminate task if time runs out)
        task.expirationHandler = {
            print("⏰ Background discovery task expired")
        }

        // Perform peer discovery
        print("🔍 Running background peer discovery")
        meshManager.refreshPeerDiscovery()

        // Reschedule for next background period
        scheduleBackgroundDiscovery()
    }
}
