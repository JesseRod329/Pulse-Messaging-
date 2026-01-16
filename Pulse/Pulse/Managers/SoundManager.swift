//
//  SoundManager.swift
//  Pulse
//
//  Handles sound effects for the app.
//

import Foundation
import AudioToolbox
import AVFoundation
import UIKit

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    private var audioPlayer: AVAudioPlayer?

    private init() {
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true

        // Configure audio session for mixing with other audio
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
    }

    // MARK: - Message Sounds

    /// Play sound when sending a message
    func playSendSound() {
        guard soundEnabled else { return }
        // Use system sound for sending (swoosh)
        AudioServicesPlaySystemSound(1004) // Mail sent sound
    }

    /// Play sound when receiving a message
    func playReceiveSound() {
        guard soundEnabled else { return }
        // Use system sound for receiving
        AudioServicesPlaySystemSound(1003) // Mail received sound
    }

    /// Play sound for new peer discovered
    func playPeerDiscoveredSound() {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(1057) // Tink sound
    }

    /// Play sound for connection established
    func playConnectedSound() {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(1054) // Pop sound
    }

    /// Play sound for error
    func playErrorSound() {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(1053) // Error sound
    }

    // MARK: - Haptic + Sound Combos

    /// Send message with haptic and sound
    func messageSent() {
        playSendSound()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Receive message with haptic and sound
    func messageReceived() {
        playReceiveSound()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Peer discovered with haptic and sound
    func peerDiscovered() {
        playPeerDiscoveredSound()
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Connection established with haptic and sound
    func connected() {
        playConnectedSound()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
