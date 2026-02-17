import SwiftUI

struct DispatchShellView<Header: View, MapSection: View, StopList: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let mapSection: () -> MapSection
    @ViewBuilder let stopList: () -> StopList
    @ViewBuilder let actionBar: () -> DispatchActionBar

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header()
                mapSection()
                stopList()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar()
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
    }
}
