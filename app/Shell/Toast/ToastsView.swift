import OpenspotCore
import SwiftUI

struct ToastsView: View {
    let toasts: Toasts

    var body: some View {
        ZStack {
            if let front = toasts.front {
                ToastSurface(toasts: toasts, front: front)
            }
        }
        .environment(\.spotIsShown, toasts.isShown)
        .padding(SpotTokens.toastRoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(SpotLoadedTheme.shared.layout)
    }
}
