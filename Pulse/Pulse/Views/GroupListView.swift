//
//  GroupListView.swift
//  Pulse
//
//  Display and manage group chats.
//

import SwiftUI

struct GroupListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var meshManager: MeshManager
    @State private var groups: [Group] = []
    @State private var selectedGroup: Group?
    @State private var showCreateGroup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(Font.pulseDisplay)
                            .foregroundStyle(.secondary)

                        Text("No Groups Yet")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Create a group from the quick actions to get started")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)

                        Button(action: { showCreateGroup = true }) {
                            Text("Create Group")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                } else {
                    List(groups) { group in
                        NavigationLink(destination: GroupChatView(group: group, meshManager: meshManager)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("\(group.members.count) members")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateGroup = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .onAppear {
            loadGroups()
        }
        .sheet(isPresented: $showCreateGroup, onDismiss: {
            loadGroups()
        }) {
            CreateGroupView(meshManager: meshManager)
        }
    }

    private func loadGroups() {
        groups = PersistenceManager.shared.getAllGroups()
    }
}

#Preview {
    GroupListView()
        .environmentObject(MeshManager())
}
