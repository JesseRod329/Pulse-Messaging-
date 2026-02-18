import SwiftUI
import BoppyV2Core

struct InventoryCatalogView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var inventoryStore: InventoryStore
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var isNewItemPresented = false
    @State private var editingItem: InventoryItem?
    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var lowStockDotSize: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 10

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 10) {
                    searchField
                    categoryChips

                    ForEach(filteredItems) { item in
                        inventoryRow(item)
                            .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                            .onTapGesture {
                                editingItem = item
                            }
                    }

                    if filteredItems.isEmpty {
                        Text("No inventory matches this filter.")
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await coordinator.refreshInventoryAndAudit()
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())

            FloatingActionButton(title: "New Item", icon: .add) {
                isNewItemPresented = true
            }
            .padding(.trailing, 18)
            .padding(.bottom, AppTheme.fabBottomPadding)
            .accessibilityLabel("New inventory item")
            .accessibilityHint("Opens the new item form.")
            .accessibilityIdentifier("profile.inventory.fab")
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isNewItemPresented) {
            NavigationStack {
                NewItemView { draft in
                    Task {
                        await coordinator.createInventoryItem(from: draft)
                        isNewItemPresented = false
                    }
                }
            }
        }
        .fullScreenCover(item: $editingItem) { item in
            NavigationStack {
                EditItemView(item: item) { draft in
                    Task {
                        await coordinator.updateInventoryItem(from: draft)
                        editingItem = nil
                    }
                }
            }
        }
    }

    private var items: [InventoryItem] {
        inventoryStore.inventoryCatalog?.items ?? []
    }

    private var categories: [String] {
        let values = Set(items.compactMap { $0.category }.filter { !$0.isEmpty })
        return ["All"] + values.sorted()
    }

    private var filteredItems: [InventoryItem] {
        items.filter { item in
            let categoryMatch = selectedCategory == "All" || item.category == selectedCategory || (selectedCategory == "Low Stock" && item.stockOnHand <= item.lowStockThreshold)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let searchMatch = query.isEmpty || item.name.lowercased().contains(query) || item.sku.lowercased().contains(query)
            return categoryMatch && searchMatch
        }
    }

    private var searchField: some View {
        SearchField(placeholder: "Search name or SKU", text: $searchText)
            .accessibilityIdentifier("profile.inventory.search")
    }

    private var categoryChips: some View {
        let renderedCategories = categories + (categories.contains("Low Stock") ? [] : ["Low Stock"])
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(renderedCategories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category,
                        statusDot: category == "Low Stock" ? AppTheme.warning : nil
                    ) {
                        selectedCategory = category
                    }
                    .accessibilityLabel("\(category) category")
                    .accessibilityHint("Filters inventory to \(category.lowercased()) items.")
                    .accessibilityIdentifier("profile.inventory.category.\(category.lowercased().replacingOccurrences(of: " ", with: ""))")
                }
            }
        }
    }

    private func inventoryRow(_ item: InventoryItem) -> some View {
        HStack(spacing: 10) {
            thumbnail(urlString: item.thumbnailURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(item.sku)
                        .font(.system(size: AppTheme.typeCaption, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted)

                    if item.defaultPriceCents > 0 {
                        Text(Self.formatPrice(item.defaultPriceCents))
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                HStack(spacing: 8) {
                    if item.stockOnHand <= item.lowStockThreshold {
                        PulseDot(color: AppTheme.danger, size: lowStockDotSize)
                    }

                    Text(stockText(item))
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                        .foregroundStyle(stockColor(item))

                    if let activeOrderCount = item.activeOrderCount, activeOrderCount > 0 {
                        Text("\(activeOrderCount) active")
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentBlue.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.accentBlue)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: AppTheme.typeCaption, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(rowPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surface.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), SKU \(item.sku), \(stockText(item))")
        .accessibilityValue(activeOrderSummary(item))
        .accessibilityIdentifier("profile.inventory.row.\(item.id)")
    }

    private func thumbnail(urlString: String?) -> some View {
        Group {
            if let urlString,
               let url = URL(string: urlString),
               !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
            .fill(AppTheme.surfaceElevated)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(AppTheme.textMuted)
            )
    }

    private func stockText(_ item: InventoryItem) -> String {
        if item.stockOnHand <= item.lowStockThreshold {
            return "CRITICAL"
        }
        return "\(item.stockOnHand) UNITS"
    }

    private func stockColor(_ item: InventoryItem) -> Color {
        if item.stockOnHand <= item.lowStockThreshold {
            return AppTheme.danger
        }
        if item.stockOnHand <= item.lowStockThreshold + 3 {
            return AppTheme.warning
        }
        return AppTheme.accentBlue
    }

    private static func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    private func activeOrderSummary(_ item: InventoryItem) -> String {
        guard let activeOrderCount = item.activeOrderCount else {
            return "No active orders"
        }
        if activeOrderCount == 0 {
            return "No active orders"
        }
        if activeOrderCount == 1 {
            return "1 active order"
        }
        return "\(activeOrderCount) active orders"
    }
}
