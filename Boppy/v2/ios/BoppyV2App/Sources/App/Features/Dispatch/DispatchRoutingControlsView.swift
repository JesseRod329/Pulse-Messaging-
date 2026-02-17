import SwiftUI
import BoppyV2Core

struct DispatchRoutingControlsView: View {
    @Binding var selectedDriverID: String
    @Binding var startAddress: String

    let drivers: [DriverProfile]
    let isOffline: Bool
    let isBusy: Bool

    let onBuildRoute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Setup")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Picker("Driver", selection: $selectedDriverID) {
                Text("Select driver").tag("")
                ForEach(drivers) { driver in
                    Text(driver.displayName).tag(driver.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.textPrimary)
            .accessibilityLabel("Route driver")
            .accessibilityHint("Selects which driver receives this route.")

            if drivers.isEmpty {
                Text("No drivers found for this channel. Add a driver in Admin Controls first.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField("Start address (e.g. 123 Main St, Austin, TX)", text: $startAddress)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .accessibilityLabel("Start address")
                .accessibilityHint("Starting address used for route optimization.")
                .accessibilityIdentifier("dispatch.startAddress")

            Text("We convert this address to GPS automatically.")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Build Route") {
                onBuildRoute()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentBlue)
            .disabled(selectedDriverID.isEmpty || isOffline || isBusy)
            .accessibilityLabel("Build route")
            .accessibilityHint("Builds a delivery route for selected pending orders.")
            .accessibilityIdentifier("dispatch.buildRoute")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
