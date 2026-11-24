import OpenspotCore
import SwiftUI

struct ToastStackView: View {
    let toasts: Toasts

    var body: some View {
        VStack(spacing: SpotTokens.toastStackGap) {
            ForEach(toasts.shown) { toast in
                ToastView(toast: toast)
            }
        }
        .padding(SpotTokens.toastRoom)
        .onHover { toasts.hover($0) }
        .id(SpotLoadedTheme.shared.layout)
    }
}
