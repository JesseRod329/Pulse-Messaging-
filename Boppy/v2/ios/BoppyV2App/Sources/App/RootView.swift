import SwiftUI
import BoppyV2Core

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if coordinator.user == nil {
                PhoneAuthView()
            } else {
                MainShellView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenBackground()
        .overlay(alignment: .top) {
            if coordinator.isLoading {
                ProgressView("Syncing")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(AppTheme.surfaceElevated, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.top, 10)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { coordinator.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    coordinator.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(coordinator.errorMessage ?? "Unknown error")
        }
        .fullScreenCover(item: Binding(
            get: { coordinator.activeOrderPost.map(OrderSheetToken.init) },
            set: { value in
                if value == nil {
                    coordinator.activeOrderPost = nil
                    coordinator.activeOrderPrefilledQuote = nil
                }
            }
        )) { token in
            OrderRequestSheet(post: token.post)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
    }
}

private struct OrderSheetToken: Identifiable {
    let post: ChannelPost
    var id: String { post.id }
}
