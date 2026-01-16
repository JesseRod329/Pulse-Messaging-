//
//  VoiceNoteManager.swift
//  Pulse
//
//  Handles voice note recording, playback, and encryption.
//

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
final class VoiceNoteManager: NSObject, ObservableObject {
    static let shared = VoiceNoteManager()

    // MARK: - Published State

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var currentPlaybackTime: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = []

    // MARK: - Audio Components

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var levelTimer: Timer?

    // MARK: - Recording State

    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?

    // Max recording duration (60 seconds)
    private let maxRecordingDuration: TimeInterval = 60

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        // Request microphone permission
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard granted else {
                    print("❌ Microphone permission denied")
                    return
                }
                self?.beginRecording()
            }
        }
    }

    private func beginRecording() {
        // Create unique file URL
        let fileName = "voice_\(UUID().uuidString).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        currentRecordingURL = audioURL

        // Recording settings (AAC for good quality/size balance)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0
            audioLevels = []
            recordingStartTime = Date()

            // Start duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRecordingDuration()
                }
            }

            // Start level metering
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAudioLevels()
                }
            }

            // Haptic feedback
            let feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.medium)
            feedbackGenerator.impactOccurred()

            print("🎤 Recording started: \(audioURL.lastPathComponent)")
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }

    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)

        // Auto-stop at max duration
        if recordingDuration >= maxRecordingDuration {
            _ = stopRecording()
        }
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }

        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)

        // Normalize level from dB (-160 to 0) to 0-1 range
        let normalizedLevel = max(0, (level + 50) / 50)

        // Keep last 50 levels for waveform
        audioLevels.append(CGFloat(normalizedLevel))
        if audioLevels.count > 50 {
            audioLevels.removeFirst()
        }
    }

    func stopRecording() -> (url: URL, duration: TimeInterval, data: Data)? {
        guard isRecording, let recorder = audioRecorder else { return nil }

        recorder.stop()
        isRecording = false

        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
        generator.impactOccurred()

        guard let url = currentRecordingURL,
              FileManager.default.fileExists(atPath: url.path),
              let audioData = try? Data(contentsOf: url) else {
            print("❌ Failed to read recorded audio")
            return nil
        }

        let duration = recordingDuration
        print("🎤 Recording stopped: \(String(format: "%.1f", duration))s, \(audioData.count) bytes")

        return (url: url, duration: duration, data: audioData)
    }

    func cancelRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        // Delete the file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        currentRecordingURL = nil
        recordingDuration = 0
        audioLevels = []

        print("🎤 Recording cancelled")
    }

    // MARK: - Playback

    func play(data: Data) {
        guard !isPlaying else {
            stopPlayback()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            playbackProgress = 0
            currentPlaybackTime = 0

            // Start playback timer
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updatePlaybackProgress()
                }
            }

            print("▶️ Playback started")
        } catch {
            print("❌ Failed to play audio: \(error)")
        }
    }

    func play(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load audio from URL")
            return
        }
        play(data: data)
    }

    private func updatePlaybackProgress() {
        guard let player = audioPlayer else { return }

        currentPlaybackTime = player.currentTime
        playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        currentPlaybackTime = 0

        playbackTimer?.invalidate()
        playbackTimer = nil

        print("⏹️ Playback stopped")
    }

    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = player.duration * progress
        playbackProgress = progress
    }

    // MARK: - Encryption

    /// Encrypt audio data for sending
    func encryptAudioData(_ data: Data, for recipientPublicKey: Data) -> Data? {
        return IdentityManager.shared.encryptMessage(data.base64EncodedString(), for: recipientPublicKey)
    }

    /// Decrypt received audio data
    func decryptAudioData(_ encryptedData: Data) -> Data? {
        guard let decryptedString = IdentityManager.shared.decryptMessage(encryptedData),
              let audioData = Data(base64Encoded: decryptedString) else {
            return nil
        }
        return audioData
    }

    // MARK: - Utilities

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Clean up old voice note files (time-based)
    func cleanupOldFiles(olderThan days: Int = 7) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])

            for file in files where file.lastPathComponent.hasPrefix("voice_") {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: file)
                    print("🗑️ Cleaned up old voice note: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Failed to cleanup old files: \(error)")
        }
    }

    /// Clean up orphaned audio files (files not referenced by any message)
    @MainActor
    func cleanupOrphanedFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let persistenceManager = PersistenceManager.shared

        // Get all audio file paths referenced by messages
        let referencedPaths = Set(persistenceManager.getAllAudioFilePaths())

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)

            var deletedCount = 0
            for file in files where file.lastPathComponent.hasPrefix("voice_") {
                // If file is not referenced by any message, delete it
                if !referencedPaths.contains(file.path) {
                    try FileManager.default.removeItem(at: file)
                    deletedCount += 1
                    print("🗑️ Cleaned up orphaned audio file: \(file.lastPathComponent)")
                }
            }

            if deletedCount > 0 {
                print("🧹 Audio cleanup: Removed \(deletedCount) orphaned file(s)")
            }
        } catch {
            print("❌ Failed to cleanup orphaned files: \(error)")
        }
    }

    /// Delete audio file referenced by a message
    func deleteAudioFile(at path: String) {
        guard !path.isEmpty else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
            print("🗑️ Deleted audio file: \(URL(fileURLWithPath: path).lastPathComponent)")
        } catch {
            print("⚠️ Failed to delete audio file at \(path): \(error)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceNoteManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("❌ Recording failed")
                isRecording = false
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("❌ Recording encode error: \(error?.localizedDescription ?? "unknown")")
            isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceNoteManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayback()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Playback decode error: \(error?.localizedDescription ?? "unknown")")
            stopPlayback()
        }
    }
}
