import OpenspotCore
import SwiftUI

struct ToastsView: View {
    let toasts: Toasts

    var body: some View {
        VStack(spacing: SpotTokens.toastBarsGap) {
            ZStack(alignment: .top) {
                ForEach(toasts.queue) { toast in
                    ToastView(toast: toast, toasts: toasts)
                        .zIndex(toast.isShown ? 1 : 0)
                }
            }
            .frame(height: toasts.frontHeight, alignment: .top)
            ToastBars(count: toasts.bars)
        }
        .padding(SpotTokens.toastRoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { toasts.hold($0) }
        .id(SpotLoadedTheme.shared.layout)
    }
}
