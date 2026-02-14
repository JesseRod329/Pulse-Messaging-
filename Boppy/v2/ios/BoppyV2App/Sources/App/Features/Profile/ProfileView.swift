import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    if let user = coordinator.user {
                        LabeledContent("Backend", value: coordinator.backendModeLabel)
                        LabeledContent("User ID", value: user.id)
                        LabeledContent("Phone", value: user.phoneE164)
                        LabeledContent("Role", value: user.role.rawValue)
                    }
                }

                Section("Delivery") {
                    Text("Invite-only channels. Followers can only view posts and request quotes.")
                    Text("Owner and drivers manage routing and stop completion.")
                }

                if coordinator.user?.role == .owner {
                    Section("Admin") {
                        AdminPanelCard(
                            title: "Inventory Catalog",
                            subtitle: "V1.5 planned. Track SKUs, stock levels, and variants.",
                            icon: "shippingbox"
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                        AdminPanelCard(
                            title: "Channels & Access",
                            subtitle: "Manage channels, invite policies, and role boundaries.",
                            icon: "person.3.sequence"
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                        AdminPanelCard(
                            title: "Ledger Controls",
                            subtitle: "View immutable audit events and retention policy status.",
                            icon: "list.bullet.clipboard"
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await coordinator.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
