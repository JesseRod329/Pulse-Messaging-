//
//  ImageMessageBubble.swift
//  Pulse
//
//  Image message display with thumbnail and full-screen viewer.
//

import SwiftUI

struct ImageMessageBubble: View {
    let message: Message
    let isFromMe: Bool
    let timestamp: Date
    let onImageTap: () -> Void

    @State private var themeManager = ThemeManager.shared
    @State private var appeared = false
    @State private var showTimestamp = false

    var body: some View {
        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
            // Image
            if let imageData = message.imageThumbnail {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            onImageTap()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Image message")
                        .accessibilityHint("Double tap to view full size")
                }
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.colors.cardBackground)
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .foregroundStyle(themeManager.colors.textSecondary)
                    )
            }

            // Timestamp toggle
            if showTimestamp {
                Text(timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(themeManager.colors.text.opacity(0.5))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Status indicators (for sent messages)
            if isFromMe {
                HStack(spacing: 4) {
                    statusText
                    HStack(spacing: 1) {
                        Image(systemName: "checkmark")
                        if message.isDelivered || message.isRead {
                            Image(systemName: "checkmark")
                                .foregroundStyle(message.isRead ? .blue : .white)
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(themeManager.colors.textSecondary.opacity(0.7))
            }
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.2)) {
                showTimestamp.toggle()
            }
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }

    private var statusText: some View {
        SwiftUI.Group {
            if message.isRead {
                Text("Read")
            } else if message.isDelivered {
                Text("Delivered")
            } else {
                Text("Sent")
            }
        }
    }
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let message: Message
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close image viewer")

                    Spacer()
                }
                .padding(20)

                Spacer()

                // Image with pinch zoom
                if let imageData = message.imageThumbnail {
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = value.magnitude
                                        }
                                        .onEnded { _ in
                                            withAnimation(.spring(response: 0.3)) {
                                                scale = 1.0
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = value.translation
                                        }
                                        .onEnded { _ in
                                            withAnimation(.spring(response: 0.3)) {
                                                offset = .zero
                                            }
                                        }
                                )
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Full screen image")
                            .accessibilityHint("Pinch to zoom, drag to pan")
                    }
                }

                Spacer()

                // Info
                VStack(spacing: 8) {
                    if let width = message.imageWidth, let height = message.imageHeight {
                        Text("\(width) × \(height)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text(message.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(20)
            }
        }
    }
}

#Preview("Image Bubble") {
    VStack(spacing: 20) {
        ImageMessageBubble(
            message: Message(
                id: "preview-1",
                senderId: "me",
                content: "",
                timestamp: Date(),
                isRead: true,
                type: .image,
                imageThumbnail: nil
            ),
            isFromMe: true,
            timestamp: Date(),
            onImageTap: {}
        )

        ImageMessageBubble(
            message: Message(
                id: "preview-2",
                senderId: "peer-1",
                content: "",
                timestamp: Date(),
                isRead: false,
                type: .image,
                imageThumbnail: nil
            ),
            isFromMe: false,
            timestamp: Date(),
            onImageTap: {}
        )

        Spacer()
    }
    .padding()
    .background(Color.black)
}
