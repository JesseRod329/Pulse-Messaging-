//
//  CreateGroupView.swift
//  Pulse
//
//  Group chat creation and management UI.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var meshManager: MeshManager

    @State private var groupName = ""
    @State private var selectedPeerIds = Set<String>()
    @State private var showError = false
    @State private var errorMessage = ""

    var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedPeerIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Group")
                        .font(.system(size: 28, weight: .bold))

                    Text("Name your group and select members to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.systemBackground))

                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        // Group Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Name")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            TextField("Enter group name", text: $groupName)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)

                        Divider()

                        // Members Selection
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Select Members")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                if !selectedPeerIds.isEmpty {
                                    Text("\(selectedPeerIds.count) selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if meshManager.nearbyPeers.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "network")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)

                                    Text("No Peers Nearby")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Make sure Bluetooth is enabled and nearby peers are advertising")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(meshManager.nearbyPeers) { peer in
                                        PeerSelectionRow(
                                            peer: peer,
                                            isSelected: selectedPeerIds.contains(peer.id),
                                            onTap: {
                                                if selectedPeerIds.contains(peer.id) {
                                                    selectedPeerIds.remove(peer.id)
                                                } else {
                                                    selectedPeerIds.insert(peer.id)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }

                Divider()

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundStyle(.primary)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }

                    Button(action: createGroup) {
                        Text("Create Group")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundStyle(.white)
                            .background(
                                canCreate ?
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(8)
                    }
                    .disabled(!canCreate)
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a group name"
            showError = true
            return
        }

        guard !selectedPeerIds.isEmpty else {
            errorMessage = "Please select at least one member"
            showError = true
            return
        }

        let groupId = UUID().uuidString
        var memberIds = Array(selectedPeerIds)
        memberIds.append("me") // Add self to group

        let newGroup = Group(
            id: groupId,
            name: trimmedName,
            creatorId: "me",
            members: memberIds,
            createdAt: Date(),
            lastMessageTime: Date()
        )

        // Persist the group
        PersistenceManager.shared.saveGroup(newGroup)

        // TODO: Notify selected members about group creation via mesh

        dismiss()
    }
}

// MARK: - Peer Selection Row
struct PeerSelectionRow: View {
    let peer: PulsePeer
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.handle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(peer.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if peer.status == .active {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

#Preview {
    CreateGroupView(
        meshManager: MeshManager()
    )
}
