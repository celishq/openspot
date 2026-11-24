import OpenspotCore
import SwiftUI

struct ToastStackView: View {
    let toasts: Toasts

    var body: some View {
        VStack(spacing: SpotTokens.toastBarsGap) {
            ZStack(alignment: .top) {
                ForEach(toasts.shown) { toast in
                    ToastView(toast: toast, toasts: toasts)
                        .zIndex(toast.isShown ? 1 : 0)
                }
            }
            .frame(height: toasts.frontHeight, alignment: .top)
            ToastBars(count: toasts.count)
        }
        .padding(SpotTokens.toastRoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { toasts.hold($0) }
        .id(SpotLoadedTheme.shared.layout)
    }
}
