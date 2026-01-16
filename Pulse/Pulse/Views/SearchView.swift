//
//  SearchView.swift
//  Pulse
//
//  Message search with filtering by conversation and date range.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var chatManager: ChatManager
    let peerId: String?
    let onSelectMessage: (Message) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var showDateFilter = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var themeManager = ThemeManager.shared

    var searchResults: [Message] {
        if searchText.isEmpty {
            return []
        }

        let persistence = PersistenceManager.shared

        if let peerId = peerId {
            // Search in specific conversation
            return persistence.searchMessages(
                in: peerId,
                query: searchText,
                startDate: startDate,
                endDate: endDate
            )
        } else {
            // Global search - filter manually since we need to decrypt
            let allResults = persistence.allMessages()
            return allResults.filter { message in
                let matchesQuery = message.content.lowercased().contains(searchText.lowercased())
                let matchesDateRange = message.timestamp >= startDate && message.timestamp <= endDate
                return matchesQuery && matchesDateRange
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.pulseHandle)
                        .foregroundStyle(themeManager.colors.textSecondary)

                    TextField(
                        "Search messages",
                        text: $searchText
                    )
                    .font(.body)
                    .textInputAutocapitalization(.never)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.pulseBody)
                                .foregroundStyle(themeManager.colors.textSecondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)

                // Filter button
                HStack {
                    Button(action: { showDateFilter.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.pulseLabel)
                            Text("Filter by date")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(themeManager.colors.accent)
                    }
                    .accessibilityLabel("Filter search by date range")

                    Spacer()

                    if startDate != Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date() ||
                        endDate != Date() {
                        Button(action: resetDateFilter) {
                            Text("Reset")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(themeManager.colors.textSecondary)
                        }
                        .accessibilityLabel("Reset date filter")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if showDateFilter {
                    DateFilterView(
                        startDate: $startDate,
                        endDate: $endDate,
                        themeManager: themeManager
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Results or empty state
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(themeManager.colors.textSecondary.opacity(0.5))

                        Text("Search messages")
                            .font(.headline)
                            .foregroundStyle(themeManager.colors.text)

                        Text("Type to find messages in your conversations")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Empty search state")

                    Spacer()
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(themeManager.colors.error.opacity(0.5))

                        Text("No results")
                            .font(.headline)
                            .foregroundStyle(themeManager.colors.text)

                        Text("No messages match \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No search results")
                    .accessibilityValue("\(searchText)")

                    Spacer()
                } else {
                    List {
                        ForEach(searchResults) { message in
                            SearchResultRow(
                                message: message,
                                onSelect: {
                                    onSelectMessage(message)
                                    onDismiss()
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(themeManager.colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.pulseHandle)
                            Text("Back")
                        }
                        .foregroundStyle(themeManager.colors.accent)
                    }
                    .accessibilityLabel("Close search")
                }

                ToolbarItem(placement: .principal) {
                    Text("Search")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(themeManager.colors.text)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func resetDateFilter() {
        startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        endDate = Date()
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let message: Message
    let onSelect: () -> Void

    @State private var themeManager = ThemeManager.shared

    var displayText: String {
        if message.type == .voice {
            return "🎤 Voice note"
        } else if message.type == .code {
            return "💻 \(message.codeLanguage ?? "Code")"
        } else {
            return message.content.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayText)
                            .font(.body)
                            .foregroundStyle(themeManager.colors.text)
                            .lineLimit(2)

                        Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.pulseSectionHeader)
                        .foregroundStyle(themeManager.colors.accent.opacity(0.6))
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Message")
            .accessibilityValue("\(displayText), \(message.timestamp.formatted(date: .abbreviated, time: .shortened))")
            .accessibilityHint("Tap to view in conversation")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Filter View

struct DateFilterView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("From")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(themeManager.colors.textSecondary)

                    DatePicker(
                        "Start date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("To")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(themeManager.colors.textSecondary)

                    DatePicker(
                        "End date",
                        selection: $endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(themeManager.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview("Search Empty") {
    let mockPeer = PulsePeer(
        id: "preview-peer",
        handle: "PreviewDev",
        status: .active,
        techStack: ["Swift", "iOS"],
        distance: 5.0,
        publicKey: nil,
        signingPublicKey: nil
    )
    let mockChatManager = ChatManager(peer: mockPeer, meshManager: MeshManager())
    SearchView(
        chatManager: mockChatManager,
        peerId: nil,
        onSelectMessage: { _ in },
        onDismiss: {}
    )
}

#Preview("Search Results") {
    let mockPeer = PulsePeer(
        id: "preview-peer",
        handle: "PreviewDev",
        status: .active,
        techStack: ["Swift", "iOS"],
        distance: 5.0,
        publicKey: nil,
        signingPublicKey: nil
    )
    let mockChatManager = ChatManager(peer: mockPeer, meshManager: MeshManager())
    SearchView(
        chatManager: mockChatManager,
        peerId: "test-peer",
        onSelectMessage: { _ in },
        onDismiss: {}
    )
}
