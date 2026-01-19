//
//  ChatView.swift
//  Pulse
//
//  Clean, minimal chat interface.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Helper Classes & Structs (Consolidated)



struct LinkPreviewView: View {
    let previewData: LinkPreviewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = previewData.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(height: 140)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = previewData.title {
                    Text(title).font(.pulseLabel).lineLimit(2)
                }
                if let description = previewData.description {
                    Text(description).font(.pulseCaption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.top, 4)
    }
}


// MARK: - ChatView Entry Point

struct ChatView: View {
    let peer: PulsePeer
    @EnvironmentObject var meshManager: MeshManager
    @StateObject private var chatManager: ChatManager

    init(peer: PulsePeer) {
        self.peer = peer
        // Create ChatManager - will be set properly after environment is available
        _chatManager = StateObject(wrappedValue: ChatManager.placeholder())
    }

    var body: some View {
        ChatContentView(peer: peer, chatManager: chatManager, meshManager: meshManager)
            .environmentObject(chatManager)
            .onAppear {
                // Initialize with actual meshManager from environment
                if !chatManager.isInitialized {
                    chatManager.initialize(peer: peer, meshManager: meshManager)
                }
            }
    }
}

// MARK: - ChatContentView (properly observes ChatManager)

struct ChatContentView: View {
    let peer: PulsePeer
    @ObservedObject var chatManager: ChatManager
    @ObservedObject var meshManager: MeshManager
    @StateObject private var voiceManager = VoiceNoteManager.shared
    @State private var messageText = ""
    @State private var showCodeShare = false
    @State private var showContent = false
    @State private var isSending = false
    @State private var isScrolledUp = false
    @State private var pendingVoiceNote: (url: URL, data: Data, duration: TimeInterval)? = nil
    @State private var showSearch = false
    @State private var selectedSearchMessage: Message? = nil
    @State private var showImagePicker = false
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var showImageViewer = false
    @State private var viewerMessage: Message? = nil
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.black, Color(white: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ZStack {
                    VStack(spacing: 0) {
                        // Header
                        chatHeader
                            .padding(.top, 60)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -20)

                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Messages
                        ScrollView {
                            GeometryReader { geometry in
                                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                            }
                            .frame(height: 0)

                            LazyVStack(spacing: 16) {
                                ForEach(chatManager.messages) { message in
                                    MessageRow(
                                        message: message,
                                        isFromMe: message.senderId == "me",
                                        peerPubkey: peer.nostrPubkey ?? peer.id,
                                        peerLightningAddress: peer.lightningAddress,
                                        showImageViewer: $showImageViewer,
                                        viewerMessage: $viewerMessage
                                    )
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                }

                                // Typing indicator
                                if chatManager.peerIsTyping {
                                    TypingIndicatorView()
                                        .id("typing")
                                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                }
                            }
                            .padding(24)
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            // Heuristic to determine if user has scrolled up significantly
                            withAnimation(.easeInOut) {
                                isScrolledUp = value < -150
                            }
                        }
                        .onChange(of: chatManager.messages.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                            isScrolledUp = false
                        }
                        .onChange(of: chatManager.peerIsTyping) { _, isTyping in
                            if isTyping {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy)
                        }
                        .opacity(showContent ? 1 : 0)

                        // Input
                        inputBar
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                    }
                    
                    // Scroll to bottom button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // Correctly call scrollToBottom with the proxy
                                scrollToBottom(proxy: proxy)
                            }) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.white, Color.black.opacity(0.6))
                                    .shadow(radius: 3)
                            }
                            .padding(.bottom, 8)
                            .padding(.trailing, 20)
                            .opacity(isScrolledUp ? 1 : 0)
                            .scaleEffect(isScrolledUp ? 1 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isScrolledUp)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCodeShare) {
            CodeShareSheet(isPresented: $showCodeShare) { code, language in
                chatManager.sendMessage(code, type: .code, language: language)
            }
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(
                chatManager: chatManager,
                peerId: peer.id,
                onSelectMessage: { message in
                    selectedSearchMessage = message
                },
                onDismiss: {
                    showSearch = false
                }
            )
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) { _, newImageItem in
            if let newImageItem = newImageItem {
                Task {
                    await handleSelectedImage(newImageItem)
                }
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let message = viewerMessage {
                FullScreenImageViewer(
                    message: message,
                    onDismiss: { showImageViewer = false }
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
    
    private func setupScrollView(proxy: ScrollViewProxy) {
        // Additional setup if needed
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatManager.messages.last {
            withAnimation(.easeOut(duration: 0.4)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 16) {
            Button(action: {
                HapticManager.shared.impact(.light)
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to nearby developers list")

            // Avatar
            ProfileImageView(size: 40, handle: peer.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.handle)
                    .font(.pulseHandle)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text(connectionStatusText)
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(peer.handle), \(connectionStatusText)")

            Spacer()

            // Search button
            Button(action: {
                HapticManager.shared.impact(.light)
                showSearch = true
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Search messages")
            .accessibilityHint("Open message search")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var connectionStatusColor: Color {
        if meshManager.isPeerConnected(peer.id) {
            return .green
        } else {
            return .orange
        }
    }

    private var connectionStatusText: String {
        if meshManager.isPeerConnected(peer.id) {
            return "Connected"
        } else {
            return "Connecting..."
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if voiceManager.isRecording {
                RecordingIndicator()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Voice preview (after recording, before sending)
            if let voiceNote = pendingVoiceNote {
                VoicePreviewView(
                    audioData: voiceNote.data,
                    duration: voiceNote.duration,
                    onSend: {
                        chatManager.sendVoiceNote(audioURL: voiceNote.url, audioData: voiceNote.data, duration: voiceNote.duration)
                        pendingVoiceNote = nil
                    },
                    onCancel: {
                        pendingVoiceNote = nil
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main input bar
            if pendingVoiceNote == nil {
                HStack(spacing: 12) {
                    // Code button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showCodeShare = true
                    }) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Share code")
                    .accessibilityHint("Opens code sharing with syntax highlighting")

                    // Image button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showImagePicker = true
                    }) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Share image")
                    .accessibilityHint("Opens photo library to send an image")

                    // Text field
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
                            if !newValue.isEmpty {
                                chatManager.userStartedTyping()
                            }
                        }
                        .onSubmit {
                            chatManager.userStoppedTyping()
                            sendMessage()
                        }
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your message here")

                    // Voice/Send button
                    if messageText.isEmpty && !voiceManager.isRecording {
                        // Voice record button
                        VoiceRecordButton { audioURL, audioData, duration in
                            withAnimation(.spring(response: 0.3)) {
                                pendingVoiceNote = (url: audioURL, data: audioData, duration: duration)
                            }
                        }
                    } else if voiceManager.isRecording {
                        // Stop recording button
                        Button(action: {
                            if let result = voiceManager.stopRecording() {
                                withAnimation(.spring(response: 0.3)) {
                                    pendingVoiceNote = (url: result.url, data: result.data, duration: result.duration)
                                }
                            }
                        }) {
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
                        // Send text button
                        Button(action: sendMessage) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .offset(y: isSending ? -20 : 0)
                                    .opacity(isSending ? 0 : 1)
                            }
                            .scaleEffect(isSending ? 0.9 : 1)
                        }
                        .disabled(isSending)
                        .animation(.spring(response: 0.2), value: isSending)
                        .accessibilityLabel("Send message")
                        .accessibilityHint("Sends your message")
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: voiceManager.isRecording)
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
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        // Haptic feedback
        HapticManager.shared.impact(.medium)

        isSending = true
        let text = messageText
        messageText = ""

        // Animate send
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3)) {
                chatManager.sendMessage(text)
            }
            isSending = false
        }
    }

    private func handleSelectedImage(_ item: PhotosPickerItem) async {
        // Load image from photos picker
        guard let imageData = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData) else {
            ErrorManager.shared.showError(.recordingFailed(reason: "Could not load image"))
            return
        }

        // Compress image
        let imageUtility = ImageUtility.shared
        guard let compressed = imageUtility.compressImage(uiImage) else {
            ErrorManager.shared.showError(.recordingFailed(reason: "Image too large to compress"))
            return
        }

        // Generate thumbnail
        let thumbnail = imageUtility.generateThumbnail(uiImage)
        let thumbnailData = thumbnail.flatMap { imageUtility.compressImage($0, maxBytes: 50_000)?.data }

        // Get dimensions
        let dimensions = imageUtility.getDimensions(uiImage)

        // Send image message
        await chatManager.sendImageMessage(
            imageData: compressed.data,
            width: dimensions.width,
            height: dimensions.height,
            thumbnail: thumbnailData
        )

        // Clear selection
        selectedImageItem = nil
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: Message
    let isFromMe: Bool
    let peerPubkey: String
    let peerLightningAddress: String?
    @Binding var showImageViewer: Bool
    @Binding var viewerMessage: Message?

    @EnvironmentObject var chatManager: ChatManager
    @ObservedObject private var zapManager = ZapManager.shared

    @State private var showEmojiPicker = false
    @State private var showZapSheet = false
    @State private var showZapDetails = false

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                switch message.type {
                case .code:
                    CodeBubble(
                        code: message.content,
                        language: message.codeLanguage ?? "text"
                    )
                case .voice:
                    if let audioData = message.audioData {
                        VoiceMessageBubble(
                            audioData: audioData,
                            duration: message.audioDuration ?? 0,
                            isFromMe: isFromMe,
                            timestamp: message.timestamp
                        )
                    }
                case .text:
                    TextBubble(
                        text: message.content,
                        isFromMe: isFromMe,
                        status: isFromMe ? message.status : .sent,
                        timestamp: message.timestamp
                    )

                    // Add link previews for text messages
                    let urls = detectURLs(in: message.content)
                    ForEach(urls, id: \.self) { url in
                        if let previewData = chatManager.linkPreviews[url.absoluteString] {
                            LinkPreviewView(previewData: previewData)
                                .onTapGesture {
                                    if let urlToOpen = URL(string: previewData.url) {
                                        UIApplication.shared.open(urlToOpen)
                                    }
                                }
                        }
                    }
                case .image:
                    ImageMessageBubble(
                        message: message,
                        isFromMe: isFromMe,
                        timestamp: message.timestamp,
                        onImageTap: {
                            viewerMessage = message
                            showImageViewer = true
                        }
                    )
                }

                // Reactions display (always show to allow adding reactions)
                ReactionDisplayView(
                    reactions: message.reactions,
                    onAddReaction: {
                        showEmojiPicker = true
                    },
                    onRemoveReaction: { emoji in
                        chatManager.removeReaction(emoji, fromMessageId: message.id)
                    },
                    currentUserId: UserDefaults.standard.string(forKey: "myPeerID") ?? "unknown"
                )

                // Zap display (only show on received messages)
                if !isFromMe {
                    ZapDisplayView(
                        messageId: message.id,
                        recipientPubkey: peerPubkey,
                        lightningAddress: peerLightningAddress,
                        onZap: {
                            showZapSheet = true
                        },
                        onShowZapDetails: {
                            showZapDetails = true
                        }
                    )
                }
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                chatManager.addReaction(emoji, toMessageId: message.id)
            }
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showZapSheet) {
            ZapAmountSheet(
                recipientHandle: message.senderId,
                lightningAddress: peerLightningAddress ?? ""
            ) { amount, comment in
                Task {
                    do {
                        try await zapManager.zapMessage(
                            messageId: message.id,
                            recipientPubkey: peerPubkey,
                            lightningAddress: peerLightningAddress ?? "",
                            amount: amount,
                            comment: comment
                        )
                    } catch {
                        // Surface the error to the user
                        ErrorManager.shared.showError(.unknown(message: "Failed to send zap: \(error.localizedDescription)"))
                        print("Zap error: \(error)")
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showZapDetails) {
            ZapDetailsSheet(
                messageId: message.id,
                zaps: zapManager.zapsForMessage(message.id)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private func detectURLs(in text: String) -> [URL] {
    do {
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }
    } catch {
        print("Failed to create URL detector: \(error)")
        return []
    }
}

struct TextBubble: View {
    let text: String
    let isFromMe: Bool
    var status: MessageStatus = .sent
    let timestamp: Date
    @State private var appeared = false
    @State private var showTimestamp = false

    var body: some View {
        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
            // Message bubble with liquid glass
            Text(text)
                .font(.pulseBody)
                .foregroundStyle(isFromMe ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        if isFromMe {
                            // Sent messages: bright glass with white fill
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)

                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.95))

                            // Subtle border
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.5),
                                            .white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        } else {
                            // Received messages: frosted glass
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)

                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.12))

                            // Glass border
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    }
                )
                .shadow(
                    color: isFromMe ? .white.opacity(0.3) : .black.opacity(0.2),
                    radius: isFromMe ? 12 : 8,
                    y: isFromMe ? 6 : 4
                )
                .onLongPressGesture {
                    withAnimation(.spring(response: 0.2)) {
                        showTimestamp.toggle()
                    }
                }

            // Timestamp (shown on long-press)
            if showTimestamp {
                Text(timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.pulseTimestamp)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Read receipt indicator for sent messages
            if isFromMe {
                HStack(spacing: 4) {
                    // Status text
                    statusText
                        .font(.pulseCaption)
                        .foregroundStyle(status == .read ? .green : .white.opacity(0.6))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    // Status icons with glow
                    HStack(spacing: 1) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(status != .sending ? .white.opacity(0.6) : .white.opacity(0.3))

                        if status == .delivered || status == .read {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(status == .read ? .green : .white.opacity(0.6))
                                .shadow(color: status == .read ? .green.opacity(0.5) : .clear, radius: 4)
                        }
                    }
                    .symbolEffect(.bounce, value: status)
                }
                .padding(.trailing, 4)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: status)
            }
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isFromMe ? "You" : "They") said: \(text)")
        .accessibilityValue(readReceiptAccessibilityValue)
        .accessibilityHint("Double tap to show timestamp")
    }

    private var statusText: Text {
        switch status {
        case .sending: return Text("Sending...")
        case .sent: return Text("Sent")
        case .delivered: return Text("Delivered")
        case .read: return Text("Read")
        }
    }

    private var readReceiptAccessibilityValue: String {
        switch status {
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        }
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]
    @State private var dotOpacity: [Double] = [1, 1, 1]
    @State private var bubbleScale: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            // Typing bubble with animated dots - liquid glass
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[index])
                        .opacity(dotOpacity[index])
                        .shadow(color: .white.opacity(0.3), radius: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Frosted glass background
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)

                    // Subtle tint
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.cyan.opacity(0.1))

                    // Glass border
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(bubbleScale)
            .shadow(color: .cyan.opacity(0.15), radius: 8, y: 4)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // "typing" text indicator
            HStack(spacing: 2) {
                Text("typing")
                    .font(.pulseTimestamp)
                    .foregroundStyle(.white.opacity(0.5))

                Image(systemName: "ellipsis")
                    .font(.pulseTimestamp)
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -1)
            }

            Spacer(minLength: 60)
        }
        .onAppear {
            animateDots()
            animateBubble()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Peer is typing")
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 1.2
                dotOpacity[i] = 0.4
            }
        }
    }

    private func animateBubble() {
        withAnimation(
            .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            bubbleScale = 1.02
        }
    }
}

struct CodeBubble: View {
    let code: String
    let language: String
    @State private var copied = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(languageColor)
                        .frame(width: 8, height: 8)

                    Text(language.uppercased())
                        .font(.pulseCaption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        if copied {
                            Text("Copied!")
                                .font(.pulseCaption)
                        }
                    }
                    .foregroundStyle(copied ? .green : .white.opacity(0.4))
                    .animation(.easeInOut(duration: 0.2), value: copied)
                }
                .accessibilityLabel(copied ? "Copied" : "Copy code")
                .accessibilityHint("Copies code to clipboard")
            }

            Text(code)
                .font(.pulseCode)
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                appeared = true
            }
        }
    }

    private var languageColor: Color {
        switch language.lowercased() {
        case "swift": return .orange
        case "python": return .blue
        case "javascript", "js": return .yellow
        case "typescript", "ts": return .blue
        case "rust": return .orange
        case "go": return .cyan
        default: return .gray
        }
    }

    private func copyCode() {
        // Haptic feedback
        HapticManager.shared.notify(.success)

        // SECURITY: Use ClipboardManager with auto-clear for code snippets
        // Code may contain sensitive information (API keys, credentials, etc.)
        ClipboardManager.shared.copy(code, sensitive: true)

        withAnimation {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

// MARK: - Code Share Sheet

struct CodeShareSheet: View {
    @Binding var isPresented: Bool
    let onShare: (String, String) -> Void

    @State private var code = ""
    @State private var selectedLanguage = "Swift"

    let languages = ["Swift", "Python", "JavaScript", "Rust", "Go", "TypeScript"]

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") { isPresented = false }
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Closes code sharing")

                    Spacer()

                    Text("Share Code")
                        .font(.pulseNavigation)
                        .foregroundStyle(.white)

                    Spacer()

                    Button("Send") {
                        HapticManager.shared.impact(.medium)
                        onShare(code, selectedLanguage)
                        isPresented = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(code.isEmpty ? .white.opacity(0.3) : .white)
                    .disabled(code.isEmpty)
                    .accessibilityLabel("Send code")
                    .accessibilityHint("Sends the code snippet")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Language picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(languages, id: \.self) { lang in
                            Button(action: { selectedLanguage = lang }) {
                                Text(lang)
                                    .font(.pulseLabel)
                                    .foregroundStyle(selectedLanguage == lang ? .black : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedLanguage == lang ? Color.white : Color.white.opacity(0.1))
                                    )
                            }
                            .accessibilityLabel(lang)
                            .accessibilityValue(selectedLanguage == lang ? "Selected" : "Not selected")
                            .accessibilityHint("Selects \(lang) syntax highlighting")
                            .accessibilityAddTraits(selectedLanguage == lang ? [.isSelected] : [])
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Code editor
                TextEditor(text: $code)
                    .font(.pulseCode)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

#Preview {
    ChatView(
        peer: PulsePeer(
            id: "1",
            handle: "@swift_dev",
            status: .active,
            techStack: ["Swift", "iOS"],
            distance: 12,
            publicKey: nil,
            signingPublicKey: nil,
            lightningAddress: "swiftdev@getalby.com",
            nostrPubkey: "npub1examplepubkey"
        )
    )
    .environmentObject(MeshManager())
}

// MARK: - PreferenceKey for Scroll Offset

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

