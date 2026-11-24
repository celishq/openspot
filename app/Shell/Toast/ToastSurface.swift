import OpenspotCore
import SwiftUI

struct ToastSurface: View {
    let toasts: Toasts
    let front: Toast

    var body: some View {
        let shape = SpotRoundShape(radius: SpotTokens.toastRadius)
        ZStack {
            ToastView(toast: front)
                .id(front.id)
                .fixedSize()
        }
        .frame(width: toasts.frontSize.width, height: toasts.frontSize.height)
        .clipShape(shape)
        .modifier(SpotGlass(shape: shape))
        .contentShape(shape)
        .onTapGesture { toasts.press(front.id) }
        .allowsHitTesting(toasts.isShown)
    }
}
