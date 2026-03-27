//
//  ChatInputBarView.swift
//  Pulse
//
//  Message input bar with text, voice, and image support
//

import SwiftUI
import PhotosUI

struct ChatInputBarView: View {
    @Binding var messageText: String
    @ObservedObject var voiceManager: VoiceNoteManager
    @Binding var pendingVoiceNote: (url: URL, data: Data, duration: TimeInterval)?
    @FocusState var isInputFocused: Bool

    let onShowCodeShare: () -> Void
    let onShowImagePicker: () -> Void
    let onSendMessage: () -> Void
    let onStopRecording: () -> Void
    let onSendVoiceNote: (URL, Data, TimeInterval) -> Void
    let onCancelVoiceNote: () -> Void
    let onTypingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if voiceManager.isRecording {
                RecordingIndicator()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let voiceNote = pendingVoiceNote {
                VoicePreviewView(
                    audioData: voiceNote.data,
                    duration: voiceNote.duration,
                    onSend: {
                        onSendVoiceNote(voiceNote.url, voiceNote.data, voiceNote.duration)
                        pendingVoiceNote = nil
                    },
                    onCancel: {
                        onCancelVoiceNote()
                        pendingVoiceNote = nil
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if pendingVoiceNote == nil {
                mainInputBar
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.black
                .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
        )
        .animation(.spring(response: 0.3), value: voiceManager.isRecording)
        .animation(.spring(response: 0.3), value: pendingVoiceNote != nil)
    }

    @ViewBuilder
    private var mainInputBar: some View {
        HStack(spacing: 12) {
            Button(action: { onShowCodeShare() }) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Share code")
            .accessibilityHint("Opens code sharing with syntax highlighting")

            Button(action: { onShowImagePicker() }) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Share image")
            .accessibilityHint("Opens photo library to send an image")

            TextField("Message", text: $messageText)
                .font(.pulseBody)
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(isInputFocused ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                )
                .onChange(of: messageText) { _, newValue in
                    onTypingChanged(!newValue.isEmpty)
                }
                .onSubmit {
                    onTypingChanged(false)
                    onSendMessage()
                }
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message here")

            if messageText.isEmpty && !voiceManager.isRecording {
                VoiceRecordButton { audioURL, audioData, duration in
                    withAnimation(.spring(response: 0.3)) {
                        pendingVoiceNote = (url: audioURL, data: audioData, duration: duration)
                    }
                }
            } else if voiceManager.isRecording {
                Button(action: onStopRecording) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 44, height: 44)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 16, height: 16)
                    }
                }
                .accessibilityLabel("Stop recording")
                .accessibilityHint("Stops voice recording and prepares to send")
            } else {
                Button(action: onSendMessage) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends your message")
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: voiceManager.isRecording)
    }
}
