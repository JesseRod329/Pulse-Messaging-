import SwiftUI
import PhotosUI
import UIKit

struct NewItemView: View {
    let onSubmit: (InventoryDraftInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    @State private var name = ""
    @State private var sku = ""
    @State private var description = ""
    @State private var category = "General"
    @State private var quantity = 8
    @State private var lowStockThreshold = 2
    @State private var lowStockAlert = true
    @State private var showInCatalog = true
    @State private var mediaItems: [String] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []

    @State private var retail = "12.00"
    @State private var wholesale = ""
    @State private var distributor = ""
    @State private var bulk = ""
    @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var sectionPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var mediaAttachHeight: CGFloat = 90
    @ScaledMetric(relativeTo: .body) private var mediaPreviewSize: CGFloat = 72

    private let categories = ["General", "Lighting", "Hardware", "Packaging"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text("New Item")
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
                    .accessibilityHint("Selects the catalog category for this item.")
                    .accessibilityIdentifier("profile.newItem.category")
                }

                mediaCard

                fieldCard("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .accessibilityLabel("Item description")
                        .accessibilityHint("Describe the item for catalog and dispatch context.")
                        .accessibilityIdentifier("profile.newItem.description")
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
                        Text("Initial quantity")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Stepper("", value: $quantity, in: 0...500)
                            .labelsHidden()
                            .accessibilityLabel("Initial quantity")
                            .accessibilityHint("Adjusts starting stock count.")
                            .accessibilityIdentifier("profile.newItem.initialQuantity")
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
                            .accessibilityHint("Adjusts the stock level that triggers low stock state.")
                            .accessibilityIdentifier("profile.newItem.lowStockThreshold")
                        Text("\(lowStockThreshold)")
                            .font(AppTheme.inter(AppTheme.typeFootnote, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(minWidth: 32)
                    }

                    Toggle("Low stock alert", isOn: $lowStockAlert)
                        .tint(AppTheme.accentBlue)
                        .accessibilityHint("Enables alerts when stock reaches the selected threshold.")
                        .accessibilityIdentifier("profile.newItem.lowStockAlert")
                    Toggle("Show in catalog", isOn: $showInCatalog)
                        .tint(AppTheme.accentBlue)
                        .accessibilityHint("Controls whether this item is visible in the catalog.")
                        .accessibilityIdentifier("profile.newItem.showInCatalog")
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
        .navigationTitle("New Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Cancel new item")
                    .accessibilityHint("Dismisses this form without saving.")
                    .accessibilityIdentifier("profile.newItem.cancel")

                Button("Save Item") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentBlue)
                .disabled(!canSubmit)
                .accessibilityLabel("Save item")
                .accessibilityHint("Creates this inventory item.")
                .accessibilityIdentifier("profile.newItem.save")
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 10)
            .background(AppTheme.navBar.opacity(0.95))
        }
    }

    private var mediaCard: some View {
        fieldCard("Media") {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .stroke(AppTheme.accentBlue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(height: mediaAttachHeight)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "camera")
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Tap to attach photos")
                                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attach photos")
            .accessibilityHint("Opens photo library to select product images.")
            .accessibilityIdentifier("profile.newItem.attachMedia")
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
                                .accessibilityHint("Removes this selected media item.")
                                .accessibilityIdentifier("profile.newItem.removeMedia.\(idx)")
                            }
                        }
                    }
                }
            }
        }
    }

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
                itemID: nil,
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
                .accessibilityIdentifier("profile.newItem.field.\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
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
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityLabel("\(title) price")
                .accessibilityIdentifier("profile.newItem.price.\(title.lowercased())")
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
        mediaItems = urls
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
