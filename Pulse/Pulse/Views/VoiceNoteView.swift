//
//  VoiceNoteView.swift
//  Pulse
//
//  Voice note recording and playback UI components.
//

import SwiftUI

// MARK: - Voice Note Recording Button

struct VoiceRecordButton: View {
    @StateObject private var voiceManager = VoiceNoteManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var isPressing = false
    @State private var pulseAnimation = false

    let onRecordingComplete: (URL, Data, TimeInterval) -> Void

    var body: some View {
        ZStack {
            // Pulse ring when recording
            if voiceManager.isRecording {
                Circle()
                    .stroke(themeManager.colors.error.opacity(0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseAnimation ? 1.3 : 1)
                    .opacity(pulseAnimation ? 0 : 0.8)
            }

            // Main button
            Circle()
                .fill(voiceManager.isRecording ? themeManager.colors.error : themeManager.colors.accent)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .scaleEffect(isPressing ? 0.9 : 1)
                .shadow(color: (voiceManager.isRecording ? themeManager.colors.error : themeManager.colors.accent).opacity(0.4), radius: 8, y: 4)
        }
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
            withAnimation(.spring(response: 0.2)) {
                isPressing = pressing
            }
        }) {
            // Long press complete - handled by tap
        }
        .accessibilityLabel(voiceManager.isRecording ? "Stop recording" : "Record voice note")
        .accessibilityHint(voiceManager.isRecording ? "Tap to stop recording" : "Tap to start recording a voice message")
        .onChange(of: voiceManager.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
    }

    private func handleTap() {
        if voiceManager.isRecording {
            // Stop recording
            if let result = voiceManager.stopRecording() {
                onRecordingComplete(result.url, result.data, result.duration)
            }
        } else {
            // Start recording
            voiceManager.startRecording()
        }
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    @StateObject private var voiceManager = VoiceNoteManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var dotAnimation = false

    var body: some View {
        HStack(spacing: 12) {
            // Recording dot
            Circle()
                .fill(themeManager.colors.error)
                .frame(width: 10, height: 10)
                .opacity(dotAnimation ? 0.3 : 1)

            // Duration
            Text(voiceManager.formatDuration(voiceManager.recordingDuration))
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(themeManager.colors.text)

            // Waveform
            WaveformView(levels: voiceManager.audioLevels, color: themeManager.colors.error)
                .frame(width: 80, height: 24)

            Spacer()

            // Cancel button
            Button {
                voiceManager.cancelRecording()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            .accessibilityLabel("Cancel recording")
            .accessibilityHint("Discards the voice recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording in progress, \(voiceManager.formatDuration(voiceManager.recordingDuration))")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                dotAnimation = true
            }
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [CGFloat]
    let color: Color
    let barWidth: CGFloat = 2
    let barSpacing: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(Array(normalizedLevels(for: geometry.size.width).enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(color)
                        .frame(width: barWidth, height: max(2, level * geometry.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func normalizedLevels(for width: CGFloat) -> [CGFloat] {
        let maxBars = Int(width / (barWidth + barSpacing))

        if levels.isEmpty {
            return Array(repeating: 0.1, count: maxBars)
        }

        if levels.count <= maxBars {
            let padding = Array(repeating: CGFloat(0.1), count: maxBars - levels.count)
            return padding + levels
        }

        // Downsample if too many levels
        let step = Double(levels.count) / Double(maxBars)
        return (0..<maxBars).map { i in
            let index = Int(Double(i) * step)
            return levels[min(index, levels.count - 1)]
        }
    }
}

// MARK: - Voice Message Bubble

struct VoiceMessageBubble: View {
    let audioData: Data
    let duration: TimeInterval
    let isFromMe: Bool
    let timestamp: Date

    @StateObject private var voiceManager = VoiceNoteManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var isThisPlaying = false

    var body: some View {
        HStack(spacing: 0) {
            if isFromMe { Spacer(minLength: 60) }

            HStack(spacing: 12) {
                // Play/Pause button
                Button {
                    togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isFromMe ? .white.opacity(0.2) : themeManager.colors.accent)
                            .frame(width: 44, height: 44)

                        Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isFromMe ? .white : themeManager.colors.background)
                            .offset(x: isThisPlaying ? 0 : 2)
                    }
                }
                .accessibilityLabel(isThisPlaying ? "Pause" : "Play")
                .accessibilityHint("Voice message, \(voiceManager.formatDuration(duration)) long")

                VStack(alignment: .leading, spacing: 6) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill((isFromMe ? Color.white : themeManager.colors.accent).opacity(0.3))
                                .frame(height: 4)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isFromMe ? .white : themeManager.colors.accent)
                                .frame(width: geometry.size.width * (isThisPlaying ? voiceManager.playbackProgress : 0), height: 4)
                        }
                    }
                    .frame(height: 4)

                    // Duration
                    HStack {
                        Text(isThisPlaying ? voiceManager.formatDuration(voiceManager.currentPlaybackTime) : voiceManager.formatDuration(duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle((isFromMe ? Color.white : themeManager.colors.text).opacity(0.7))

                        Spacer()

                        // Timestamp
                        Text(timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle((isFromMe ? Color.white : themeManager.colors.text).opacity(0.5))
                    }
                }
                .frame(width: 120)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isFromMe
                    ? LinearGradient(colors: [themeManager.colors.accent, themeManager.colors.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [themeManager.colors.cardBackground, themeManager.colors.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if !isFromMe { Spacer(minLength: 60) }
        }
        .onChange(of: voiceManager.isPlaying) { _, isPlaying in
            if !isPlaying {
                isThisPlaying = false
            }
        }
    }

    private func togglePlayback() {
        if isThisPlaying {
            voiceManager.stopPlayback()
            isThisPlaying = false
        } else {
            // Stop any other playback first
            voiceManager.stopPlayback()
            voiceManager.play(data: audioData)
            isThisPlaying = true
        }
    }
}

// MARK: - Preview Voice Message (before sending)

struct VoicePreviewView: View {
    let audioData: Data
    let duration: TimeInterval
    let onSend: () -> Void
    let onCancel: () -> Void

    @StateObject private var voiceManager = VoiceNoteManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            // Play preview button
            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(themeManager.colors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.colors.accent)
                }
            }
            .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
            .accessibilityHint("Preview voice recording before sending")

            // Duration and waveform placeholder
            VStack(alignment: .leading, spacing: 4) {
                // Static waveform representation
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(themeManager.colors.accent.opacity(0.6))
                            .frame(width: 2, height: CGFloat.random(in: 4...16))
                    }
                }

                Text(voiceManager.formatDuration(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(themeManager.colors.textSecondary)
            }

            Spacer()

            // Cancel button
            Button {
                voiceManager.stopPlayback()
                onCancel()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.colors.error)
                    .frame(width: 36, height: 36)
                    .background(themeManager.colors.error.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Delete recording")
            .accessibilityHint("Discards this voice recording")

            // Send button
            Button {
                voiceManager.stopPlayback()
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(themeManager.colors.accent)
            }
            .accessibilityLabel("Send voice message")
            .accessibilityHint("Sends the voice recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onChange(of: voiceManager.isPlaying) { _, playing in
            if !playing {
                isPlaying = false
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            voiceManager.stopPlayback()
            isPlaying = false
        } else {
            voiceManager.play(data: audioData)
            isPlaying = true
        }
    }
}

#Preview("Voice Record Button") {
    VoiceRecordButton { _, _, _ in }
        .padding()
        .background(Color.black)
}

#Preview("Voice Message") {
    VStack {
        VoiceMessageBubble(
            audioData: Data(),
            duration: 12.5,
            isFromMe: true,
            timestamp: Date()
        )

        VoiceMessageBubble(
            audioData: Data(),
            duration: 8.2,
            isFromMe: false,
            timestamp: Date()
        )
    }
    .padding()
    .background(Color.black)
}
