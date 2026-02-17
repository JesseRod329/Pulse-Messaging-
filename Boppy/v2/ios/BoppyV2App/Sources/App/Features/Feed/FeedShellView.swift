import SwiftUI
import BoppyV2Core

struct FeedShellView<Content: View>: View {
    let selectedChannelTitle: String
    let onRefresh: () async -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        FeedHeaderStrip(
                            title: selectedChannelTitle,
                            subtitle: "Owner Channel"
                        )

                        content()
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, AppTheme.contentBottomPadding)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height + AppTheme.minimumViewportFill,
                        alignment: .top
                    )
                }
                .scrollDismissesKeyboard(.immediately)
                .refreshable {
                    await onRefresh()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppTheme.screenGradient)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
