//
//  ChatView.swift (Refactored)
//  Pulse
//
//  Clean, minimal chat interface.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - Main Chat View

struct ChatView: View {
    let peer: PulsePeer
    @EnvironmentObject var meshManager: MeshManager
    @StateObject private var chatManager: ChatManager

    init(peer: PulsePeer) {
        self.peer = peer
        _chatManager = StateObject(wrappedValue: ChatManager.placeholder())
    }

    var body: some View {
        ChatContentView(peer: peer, chatManager: chatManager, meshManager: meshManager)
            .environmentObject(chatManager)
            .onAppear {
                if !chatManager.isInitialized {
                    chatManager.initialize(peer: peer, meshManager: meshManager)
                }
            }
    }
}

// MARK: - Chat Content View

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
            LinearGradient(
                colors: [Color.black, Color(white: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ZStack {
                    VStack(spacing: 0) {
                        ChatHeaderView(
                            peer: peer,
                            isConnected: meshManager.isPeerConnected(peer.id),
                            onBack: { dismiss() },
                            onSearch: { showSearch = true }
                        )
                        .padding(.top, 60)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -20)

                        Divider()
                            .background(Color.white.opacity(0.1))

                        messagesScrollView(proxy: proxy)

                        ChatInputBarView(
                            messageText: $messageText,
                            voiceManager: voiceManager,
                            pendingVoiceNote: $pendingVoiceNote,
                            isInputFocused: $isInputFocused,
                            onShowCodeShare: { showCodeShare = true },
                            onShowImagePicker: { showImagePicker = true },
                            onSendMessage: sendMessage,
                            onStopRecording: stopRecording,
                            onSendVoiceNote: sendVoiceNote,
                            onCancelVoiceNote: { pendingVoiceNote = nil },
                            onTypingChanged: { chatManager.userStartedTyping() }
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    }

                    scrollToBottomButton(proxy: proxy)
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
                onDismiss: { showSearch = false }
            )
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) { _, newImageItem in
            if let newImageItem = newImageItem {
                Task { await handleSelectedImage(newImageItem) }
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
            withAnimation(.easeOut(duration: 0.4)) { showContent = true }
        }
    }

    @ViewBuilder
    private func messagesScrollView(proxy: ScrollViewProxy) -> some View {
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
                        showImageViewer: $showImageViewer,
                        viewerMessage: $viewerMessage
                    )
                    .id(message.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

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
            withAnimation(.easeInOut) { isScrolledUp = value < -150 }
        }
        .onChange(of: chatManager.messages.count) { _, _ in
            scrollToBottom(proxy: proxy)
            isScrolledUp = false
        }
        .onChange(of: chatManager.peerIsTyping) { _, isTyping in
            if isTyping {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("typing", anchor: .bottom) }
            }
        }
        .onAppear { scrollToBottom(proxy: proxy) }
        .opacity(showContent ? 1 : 0)
    }

    @ViewBuilder
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { scrollToBottom(proxy: proxy) }) {
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatManager.messages.last {
            withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        HapticManager.shared.impact(.medium)
        isSending = true
        let text = messageText
        messageText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3)) { chatManager.sendMessage(text) }
            isSending = false
        }
    }

    private func stopRecording() {
        if let result = voiceManager.stopRecording() {
            withAnimation(.spring(response: 0.3)) { pendingVoiceNote = (url: result.url, data: result.data, duration: result.duration) }
        }
    }

    private func sendVoiceNote(url: URL, data: Data, duration: TimeInterval) {
        chatManager.sendVoiceNote(audioURL: url, audioData: data, duration: duration)
    }

    private func handleSelectedImage(_ item: PhotosPickerItem) async {
        guard let imageData = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData) else {
            ErrorManager.shared.showError(.recordingFailed(reason: "Could not load image"))
            return
        }

        let imageUtility = ImageUtility.shared
        guard let compressed = imageUtility.compressImage(uiImage) else {
            ErrorManager.shared.showError(.recordingFailed(reason: "Image too large to compress"))
            return
        }

        let thumbnail = imageUtility.generateThumbnail(uiImage)
        let thumbnailData = thumbnail.flatMap { imageUtility.compressImage($0, maxBytes: 50_000)?.data }
        let dimensions = imageUtility.getDimensions(uiImage)

        await chatManager.sendImageMessage(
            imageData: compressed.data,
            width: dimensions.width,
            height: dimensions.height,
            thumbnail: thumbnailData
        )

        selectedImageItem = nil
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
