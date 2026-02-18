import SwiftUI
import PhotosUI
import UIKit
import BoppyV2Core

struct EditItemView: View {
    let item: InventoryItem
    let onSubmit: (InventoryDraftInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    @State private var name: String
    @State private var sku: String
    @State private var description: String
    @State private var category: String
    @State private var quantity: Int
    @State private var lowStockThreshold: Int
    @State private var lowStockAlert: Bool
    @State private var showInCatalog: Bool
    @State private var mediaItems: [String]
    @State private var selectedPhotos: [PhotosPickerItem] = []

    @State private var retail: String
    @State private var wholesale: String
    @State private var distributor: String
    @State private var bulk: String

    @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var sectionPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var mediaAttachHeight: CGFloat = 90
    @ScaledMetric(relativeTo: .body) private var mediaPreviewSize: CGFloat = 72

    private let categories = ["General", "Lighting", "Hardware", "Packaging"]

    init(item: InventoryItem, onSubmit: @escaping (InventoryDraftInput) -> Void) {
        self.item = item
        self.onSubmit = onSubmit

        // Parse clean description (strip metadata suffix)
        let rawDesc = item.description
        let cleanDesc: String
        if let range = rawDesc.range(of: "\ncategory=", options: .backwards) {
            cleanDesc = String(rawDesc[rawDesc.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanDesc = rawDesc
        }

        _name = State(initialValue: item.name)
        _sku = State(initialValue: item.sku)
        _description = State(initialValue: cleanDesc)
        _category = State(initialValue: item.category ?? "General")
        _quantity = State(initialValue: item.stockOnHand)
        _lowStockThreshold = State(initialValue: item.lowStockThreshold)
        _lowStockAlert = State(initialValue: item.lowStockThreshold > 0)
        _showInCatalog = State(initialValue: item.showInCatalog ?? true)

        // Pre-populate media from thumbnail
        if let thumb = item.thumbnailURL, !thumb.isEmpty {
            _mediaItems = State(initialValue: [thumb])
        } else {
            _mediaItems = State(initialValue: [])
        }

        // Convert cents to dollar strings
        _retail = State(initialValue: Self.centsToString(item.defaultPriceCents))

        // Extract variant prices
        let variants = item.variants
        _wholesale = State(initialValue: Self.variantPrice(variants, name: "Wholesale"))
        _distributor = State(initialValue: Self.variantPrice(variants, name: "Distributor"))
        _bulk = State(initialValue: Self.variantPrice(variants, name: "Bulk"))
    }

    private static func centsToString(_ cents: Int) -> String {
        if cents == 0 { return "" }
        let dollars = Double(cents) / 100.0
        return String(format: "%.2f", dollars)
    }

    private static func variantPrice(_ variants: [InventoryVariant], name: String) -> String {
        guard let v = variants.first(where: { $0.name == name && $0.isActive }) else { return "" }
        return centsToString(v.priceCents)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text("Edit Item")
                    .font(AppTheme.inter(AppTheme.typeTitle2, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                fieldCard("Basics") {
                    field("Name", text: $name)
                    field("SKU", text: $sku)

                    Text("Category")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Item category")
                    .accessibilityIdentifier("profile.editItem.category")
                }

                mediaCard

                fieldCard("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .accessibilityLabel("Item description")
                        .accessibilityIdentifier("profile.editItem.description")
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .fill(AppTheme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }

                fieldCard("Quantity + Alerts") {
                    HStack {
                        Text("Stock on hand")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Stepper("", value: $quantity, in: 0...9999)
                            .labelsHidden()
                            .accessibilityLabel("Stock quantity")
                            .accessibilityIdentifier("profile.editItem.quantity")
                        Text("\(quantity)")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(minWidth: 32)
                    }

                    HStack {
                        Text("Low stock threshold")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Stepper("", value: $lowStockThreshold, in: 0...100)
                            .labelsHidden()
                            .accessibilityLabel("Low stock threshold")
                            .accessibilityIdentifier("profile.editItem.lowStockThreshold")
                        Text("\(lowStockThreshold)")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(minWidth: 32)
                    }

                    Toggle("Low stock alert", isOn: $lowStockAlert)
                        .tint(AppTheme.accentBlue)
                        .accessibilityIdentifier("profile.editItem.lowStockAlert")
                    Toggle("Show in catalog", isOn: $showInCatalog)
                        .tint(AppTheme.accentBlue)
                        .accessibilityIdentifier("profile.editItem.showInCatalog")
                }

                fieldCard("Pricing") {
                    priceField("Retail Price", text: $retail)
                    priceField("Wholesale", text: $wholesale)
                    priceField("Distributor", text: $distributor)
                    priceField("Bulk", text: $bulk)

                    Text("Leave blank to skip a tier. Retail is required.")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Cancel editing")
                    .accessibilityIdentifier("profile.editItem.cancel")

                Button("Save Changes") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentBlue)
                .disabled(!canSubmit)
                .accessibilityLabel("Save changes")
                .accessibilityIdentifier("profile.editItem.save")
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 10)
            .background(AppTheme.navBar.opacity(0.95))
        }
    }

    // MARK: - Media

    private var mediaCard: some View {
        fieldCard("Media (Photos/Videos)") {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .any(of: [.images, .videos])
            ) {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.accentBlue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(height: mediaAttachHeight)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.badge.ellipsis")
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Tap to add photos or videos")
                                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attach media")
            .accessibilityIdentifier("profile.editItem.attachMedia")
            .onChange(of: selectedPhotos) { _, items in
                Task { await loadPhotos(items) }
            }

            if !mediaItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(mediaItems.enumerated()), id: \.offset) { idx, item in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: item)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Rectangle().fill(AppTheme.surfaceElevated)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundStyle(AppTheme.textMuted)
                                            )
                                    }
                                }
                                .frame(width: mediaPreviewSize, height: mediaPreviewSize)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous))

                                Button {
                                    mediaItems.remove(at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .background(Color.black.opacity(0.5), in: Circle())
                                }
                                .offset(x: 4, y: -4)
                                .accessibilityLabel("Remove media")
                                .accessibilityIdentifier("profile.editItem.removeMedia.\(idx)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !authStore.isOffline
        && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let retailCents = max(0, Int((Double(retail) ?? 0) * 100))
        let wholesaleCents = wholesale.isEmpty ? nil : max(0, Int((Double(wholesale) ?? 0) * 100))
        let distributorCents = distributor.isEmpty ? nil : max(0, Int((Double(distributor) ?? 0) * 100))
        let bulkCents = bulk.isEmpty ? nil : max(0, Int((Double(bulk) ?? 0) * 100))

        onSubmit(
            InventoryDraftInput(
                itemID: item.id,
                name: name,
                sku: sku,
                description: description,
                category: category,
                thumbnailURL: mediaItems.first,
                mediaItems: mediaItems,
                stockOnHand: quantity,
                lowStockThreshold: lowStockAlert ? lowStockThreshold : 0,
                defaultPriceCents: retailCents,
                wholesalePriceCents: wholesaleCents,
                distributorPriceCents: distributorCents,
                bulkPriceCents: bulkCents,
                showInCatalog: showInCatalog
            )
        )
    }

    private func fieldCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                .foregroundStyle(AppTheme.textMuted)
            content()
        }
        .padding(sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(title, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityLabel(title)
                .accessibilityIdentifier("profile.editItem.field.\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
    }

    private func priceField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 6) {
                Text("$")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("0.00", text: text)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityLabel("\(title) price")
                    .accessibilityIdentifier("profile.editItem.price.\(title.lowercased())")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var urls: [String] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.8) {
                let filename = UUID().uuidString + ".jpg"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? jpeg.write(to: tempURL)
                urls.append(tempURL.absoluteString)
            }
        }
        // Append to existing rather than replace
        mediaItems.append(contentsOf: urls)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
