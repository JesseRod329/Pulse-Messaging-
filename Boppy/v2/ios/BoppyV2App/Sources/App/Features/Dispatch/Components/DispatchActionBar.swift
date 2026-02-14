import SwiftUI

struct DispatchActionBar: View {
    let onRefresh: () -> Void
    let onBuildOrOptimize: () -> Void
    let buildButtonLabel: String
    let isBuildDisabled: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button("Refresh", action: onRefresh)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

            Button(buildButtonLabel, action: onBuildOrOptimize)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isBuildDisabled)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
