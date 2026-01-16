//
//  GroupChatView.swift
//  Pulse
//
//  Group chat interface for messaging multiple people.
//

import SwiftUI
import UIKit

struct GroupChatView: View {
    let group: Group
    @ObservedObject var meshManager: MeshManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var chatManager: ChatManager
    @State private var messageText = ""
    @State private var showContent = false
    @State private var messages: [Message] = []

    init(group: Group, meshManager: MeshManager) {
        self.group = group
        self.meshManager = meshManager
        _chatManager = StateObject(wrappedValue: ChatManager.placeholder())
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(Font.pulseNavigation)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.pulseHandle)
                            .foregroundStyle(.white)

                        Text("\(group.members.count) members")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        if messages.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Spacer()
                                    .frame(height: 100)

                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("Start the conversation")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("Messages to \(group.members.count) members will appear here")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    GroupMessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Message input
                HStack(spacing: 12) {
                    TextField("Message", text: $messageText)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)

                    Button(action: sendGroupMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(16)
            }
        }
        .onAppear {
            loadMessages()
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
    }

    private func loadMessages() {
        messages = PersistenceManager.shared.loadGroupMessages(groupId: group.id)
    }

    private func sendGroupMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let messageId = UUID().uuidString
        let timestamp = Date()

        // Create local message
        let newMessage = Message(
            id: messageId,
            senderId: "me",
            content: trimmed,
            timestamp: timestamp,
            type: .text
        )

        // Add to local array
        messages.append(newMessage)

        // Persist the message
        PersistenceManager.shared.saveGroupMessage(
            groupId: group.id,
            messageId: messageId,
            senderId: "me",
            content: trimmed,
            timestamp: timestamp
        )

        // Get peers for group members and send via mesh
        let groupPeers = group.members.compactMap { memberId in
            meshManager.nearbyPeers.first { $0.id == memberId }
        }

        if !groupPeers.isEmpty {
            chatManager.sendGroupMessage(trimmed, groupId: group.id, recipientPeers: groupPeers)
        }

        messageText = ""
        SoundManager.shared.messageSent()
    }
}

// MARK: - Group Message Bubble

struct GroupMessageBubble: View {
    let message: Message

    var isFromMe: Bool {
        message.senderId == "me"
    }

    var body: some View {
        HStack {
            if isFromMe { Spacer() }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                if !isFromMe {
                    Text(message.senderId)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFromMe ? Color.blue : Color.white.opacity(0.15))
                    )

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            if !isFromMe { Spacer() }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    GroupChatView(
        group: Group(
            id: "group1",
            name: "Dev Team",
            creatorId: "me",
            members: ["me", "peer1", "peer2"],
            createdAt: Date(),
            lastMessageTime: Date()
        ),
        meshManager: MeshManager()
    )
}
