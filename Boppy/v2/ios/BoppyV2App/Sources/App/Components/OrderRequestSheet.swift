import SwiftUI
import UIKit
import BoppyV2Core

struct OrderRequestSheet: View {
    let post: ChannelPost

    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var orderStore: OrderStore
    @Environment(\.dismiss) private var dismiss

    @State private var line1 = ""
    @State private var line2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var postalCode = ""
    @State private var quoteNote = ""

    @State private var quantity = 1
    @State private var selectedTier: PricingTier = .retail
    @ScaledMetric(relativeTo: .title3) private var heroHeight: CGFloat = 190
    @ScaledMetric(relativeTo: .body) private var quantityButtonSize: CGFloat = 36

    var body: some View {
        v2Sheet
        .onAppear {
            if quoteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let seed = orderStore.activeOrderPrefilledQuote {
                quoteNote = seed
            }
        }
    }

    private var v2Sheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroImage

                    Text(post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Product request" : post.caption)
                        .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let subtitle = post.heroSubtitle {
                        Text(subtitle)
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    specsRow

                    addressBlock

                    quantityBlock

                    tierGrid

                    noteBlock
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Order Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        orderStore.activeOrderPrefilledQuote = nil
                        dismiss()
                    }
                    .accessibilityLabel("Cancel order request")
                    .accessibilityHint("Closes the sheet without submitting this request.")
                    .accessibilityIdentifier("orderSheet.cancel")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        submit()
                    }
                    .disabled(!canSubmit)
                    .accessibilityLabel("Submit order request")
                    .accessibilityHint("Sends your request with quantity, tier, address, and details.")
                    .accessibilityIdentifier("orderSheet.submit")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
        }
    }

    private var heroImage: some View {
        Group {
            if let mediaPath = post.mediaPath,
               let url = mediaURL(from: mediaPath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderHero
                    }
                }
            } else {
                placeholderHero
            }
        }
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
    }

    private var placeholderHero: some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
            .fill(AppTheme.surfaceElevated)
            .overlay {
                Text("Product image")
                    .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
    }

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delivery Address")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            TextField("Street", text: $line1)
                .sheetInputFieldStyle()
                .accessibilityLabel("Street address")
            TextField("Apt / Suite (optional)", text: $line2)
                .sheetInputFieldStyle()
                .accessibilityLabel("Apartment or suite")

            HStack(spacing: 8) {
                TextField("City", text: $city)
                    .sheetInputFieldStyle()
                    .accessibilityLabel("City")
                TextField("State", text: $state)
                    .sheetInputFieldStyle()
                    .frame(maxWidth: 80)
                    .accessibilityLabel("State")
                TextField("ZIP", text: $postalCode)
                    .sheetInputFieldStyle()
                    .keyboardType(.numbersAndPunctuation)
                    .frame(maxWidth: 110)
                    .accessibilityLabel("ZIP code")
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var specsRow: some View {
        HStack(spacing: 16) {
            Label("Verified Seller", systemImage: "checkmark.seal.fill")
            Label("Ships in 2-4 days", systemImage: "clock")
        }
        .font(AppTheme.inter(AppTheme.typeCaption, weight: .semibold))
        .foregroundStyle(AppTheme.textMuted)
    }

    private var quantityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 10) {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Text("-")
                        .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold))
                        .frame(width: quantityButtonSize, height: quantityButtonSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease quantity")
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                Text("\(quantity)")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(minWidth: 30)

                Button {
                    quantity += 1
                } label: {
                    Text("+")
                        .font(AppTheme.inter(AppTheme.typeTitle3, weight: .bold))
                        .frame(width: quantityButtonSize, height: quantityButtonSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase quantity")
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                Spacer()

                Text(estimatedPriceText)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var tierGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pricing Tier")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(PricingTier.allCases, id: \.self) { tier in
                    Button {
                        selectedTier = tier
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tier.title)
                                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(tier.priceLabel(baseCents: basePriceCents))
                                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .fill(selectedTier == tier ? AppTheme.accentBlue.opacity(0.05) : AppTheme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .stroke(selectedTier == tier ? AppTheme.accentBlue.opacity(0.7) : AppTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tier.title) pricing tier")
                    .accessibilityHint("Sets pricing tier to \(tier.title).")
                    .accessibilityIdentifier("orderSheet.tier.\(tier.rawValue)")
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            TextEditor(text: $quoteNote)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .accessibilityLabel("Order details")
                .accessibilityHint("Describe quantity, timing, or delivery details.")
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .padding(12)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
            .fill(AppTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    private var basePriceCents: Int {
        post.priceCents ?? 6900
    }

    private var canSubmit: Bool {
        !authStore.isOffline &&
        !line1.isEmpty &&
        !city.isEmpty &&
        !state.isEmpty &&
        !postalCode.isEmpty &&
        !quoteNote.isEmpty
    }

    private var estimatedPriceText: String {
        let cents = selectedTier.priceCents(baseCents: basePriceCents) * quantity
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let value = NSDecimalNumber(value: cents).dividing(by: 100)
        return formatter.string(from: value) ?? "$\(Double(cents) / 100)"
    }

    private func submit() {
        let address = DeliveryAddress(
            line1: line1,
            line2: line2,
            city: city,
            state: state,
            postalCode: postalCode,
            country: "US"
        )

        let tierPayload = "tier=\(selectedTier.rawValue);qty=\(quantity);note=\(quoteNote)"

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            await coordinator.submitOrderRequest(
                postID: post.id,
                address: address,
                quoteNote: tierPayload
            )
            dismiss()
        }
    }

    private func mediaURL(from mediaPath: String) -> URL? {
        if let url = URL(string: mediaPath), url.scheme != nil {
            return url
        }
        if FileManager.default.fileExists(atPath: mediaPath) {
            return URL(fileURLWithPath: mediaPath)
        }
        return nil
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum PricingTier: String, CaseIterable {
    case retail
    case wholesale
    case distributor
    case bulk

    var title: String {
        rawValue.capitalized
    }

    var discountMultiplier: Double {
        switch self {
        case .retail:
            return 1.0
        case .wholesale:
            return 0.85
        case .distributor:
            return 0.75
        case .bulk:
            return 0.65
        }
    }

    func priceCents(baseCents: Int) -> Int {
        Int(Double(baseCents) * discountMultiplier)
    }

    func priceLabel(baseCents: Int) -> String {
        let cents = priceCents(baseCents: baseCents)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let value = NSDecimalNumber(value: cents).dividing(by: 100)
        return formatter.string(from: value).map { "\($0)/unit" } ?? "$\(Double(cents) / 100)/unit"
    }
}

private extension View {
    func sheetInputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .tint(AppTheme.accentBlue)
    }
}
