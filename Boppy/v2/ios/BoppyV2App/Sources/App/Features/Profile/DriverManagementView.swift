import SwiftUI
import UIKit
import BoppyV2Core

struct DriverManagementView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var feedStore: FeedStore
    @EnvironmentObject private var authStore: AuthStore

    @State private var phoneInput = ""
    @State private var isAdding = false
    @State private var feedbackMessage: String?
    @State private var feedbackIsError = false
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDriverID: String?
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                addDriverCard
                driverListCard
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("Manage Drivers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .alert("Remove Driver?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingRemoveDriverID = nil
            }
            Button("Remove", role: .destructive) {
                if let driverID = pendingRemoveDriverID {
                    Task { await coordinator.removeDriver(driverUserID: driverID) }
                }
                pendingRemoveDriverID = nil
            }
        } message: {
            Text("This driver will lose access to dispatch and order management. They can be re-added later.")
        }
    }

    // MARK: - Add Driver

    private var addDriverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Add Driver", systemImage: "person.badge.plus")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            Text("Enter the phone number of an existing user to promote them to driver.")
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                .foregroundStyle(AppTheme.textMuted)

            HStack(spacing: 8) {
                Text("+1")
                    .font(AppTheme.inter(AppTheme.typeBody, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .fill(AppTheme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )

                TextField("Phone number", text: $phoneInput)
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
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
                    .accessibilityLabel("Driver phone number")
                    .accessibilityHint("Enter the phone number to add as a driver.")
                    .accessibilityIdentifier("driverMgmt.phoneInput")
            }

            Button {
                Task { await addDriver() }
            } label: {
                HStack(spacing: 8) {
                    if isAdding {
                        ProgressView()
                            .tint(AppTheme.textPrimary)
                            .scaleEffect(0.8)
                    } else {
                        Text("Add as Driver")
                            .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(AppTheme.accentBlue)
                )
                .foregroundStyle(AppTheme.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(isAdding || resolvedPhone.count < 10)
            .accessibilityLabel("Add as driver")
            .accessibilityHint("Promotes this phone number to driver role.")
            .accessibilityIdentifier("driverMgmt.addButton")

            if let feedbackMessage {
                HStack(spacing: 6) {
                    Image(systemName: feedbackIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text(feedbackMessage)
                }
                .font(AppTheme.inter(AppTheme.typeFootnote, weight: .semibold))
                .foregroundStyle(feedbackIsError ? AppTheme.danger : AppTheme.success)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill((feedbackIsError ? AppTheme.danger : AppTheme.success).opacity(0.08))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .profileCardStyle()
    }

    // MARK: - Driver List

    private var driverListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Active Drivers", systemImage: "person.2.fill")
                .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            if feedStore.drivers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                    Text("No drivers yet")
                        .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                    Text("Add a driver above to get started.")
                        .font(AppTheme.inter(AppTheme.typeFootnote, weight: .regular))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(feedStore.drivers) { driver in
                    driverRow(driver)
                }
            }
        }
        .profileCardStyle()
    }

    private func driverRow(_ driver: DriverProfile) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.accentBlue.opacity(0.22))
                .frame(width: avatarSize, height: avatarSize)
                .overlay(
                    Text(driverInitials(driver.displayName))
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.displayName)
                    .font(AppTheme.inter(AppTheme.typeSubheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(driver.availability == "available" ? AppTheme.success : AppTheme.warning)
                        .frame(width: 6, height: 6)
                    Text(driver.availability?.capitalized ?? "Unknown")
                        .font(AppTheme.inter(AppTheme.typeCaption, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                    if let rating = driver.rating {
                        Text("\(String(format: "%.1f", rating))")
                            .font(AppTheme.inter(AppTheme.typeCaption, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }

            Spacer()

            Button(role: .destructive) {
                pendingRemoveDriverID = driver.id
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(driver.displayName)")
            .accessibilityHint("Removes this driver from the channel.")
            .accessibilityIdentifier("driverMgmt.remove.\(driver.id)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var resolvedPhone: String {
        let digits = phoneInput.filter { $0.isNumber }
        return "+1\(digits)"
    }

    private func addDriver() async {
        let phone = resolvedPhone
        guard phone.count >= 10 else { return }

        isAdding = true
        feedbackMessage = nil

        let result = await coordinator.addDriver(phoneE164: phone)

        withAnimation(.easeInOut(duration: 0.25)) {
            switch result {
            case .success(let name):
                feedbackMessage = "\(name) added as driver."
                feedbackIsError = false
                phoneInput = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .error(let message):
                feedbackMessage = message
                feedbackIsError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }

        isAdding = false

        // Auto-dismiss feedback after 4 seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation { feedbackMessage = nil }
        }
    }

    private func driverInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
