import SwiftUI
import BoppyV2Core

struct OrderRequestSheet: View {
    let post: ChannelPost

    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var line1 = ""
    @State private var line2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var quoteNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenGradient
                    .ignoresSafeArea()

                Form {
                    Section("Post") {
                        Text(post.caption)
                        Text(post.postType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Delivery Address") {
                        TextField("Street", text: $line1)
                        TextField("Apt / Suite (optional)", text: $line2)
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("ZIP", text: $postalCode)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    Section("What do you want?") {
                        TextEditor(text: $quoteNote)
                            .frame(minHeight: 120)
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(AppTheme.surface)
            }
            .navigationTitle("Order Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        coordinator.activeOrderPrefilledQuote = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("orderSheet.cancel")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let address = DeliveryAddress(
                            line1: line1,
                            line2: line2,
                            city: city,
                            state: state,
                            postalCode: postalCode,
                            country: "US"
                        )
                        Task {
                            await coordinator.submitOrderRequest(
                                postID: post.id,
                                address: address,
                                quoteNote: quoteNote
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("orderSheet.submit")
                }
            }
        }
        .onAppear {
            if quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let seed = coordinator.activeOrderPrefilledQuote
            {
                quoteNote = seed
            }
        }
    }

    private var canSubmit: Bool {
        !line1.isEmpty && !city.isEmpty && !state.isEmpty && !postalCode.isEmpty && !quoteNote.isEmpty
    }
}
