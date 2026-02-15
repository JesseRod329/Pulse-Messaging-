import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenGradient.ignoresSafeArea())
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}
