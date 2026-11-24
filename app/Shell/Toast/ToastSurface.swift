import OpenspotCore
import SwiftUI

struct ToastSurface: View {
    let toasts: Toasts
    let front: Toast
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        let size = toasts.frontSize
        let room = SpotTokens.toastMaxWidth - 2 * SpotTokens.toastRoom
        let rect = CGRect(x: (room - size.width) / 2 + toasts.frontShift, y: 0, width: size.width, height: size.height)
        let shape = SpotSurfaceShape(rect: rect, radius: SpotTokens.toastRadius)
        ZStack(alignment: .topLeading) {
            Color.clear.spotGlass(in: shape)
            ToastView(toast: front)
                .id(front.id)
                .fixedSize()
                .offset(x: rect.minX)
        }
        .frame(width: room, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipShape(shape)
        .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        .contentShape(shape)
        .onTapGesture { toasts.press(front.id) }
        .allowsHitTesting(isShown)
    }
}
