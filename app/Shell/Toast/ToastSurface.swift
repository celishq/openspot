import OpenspotCore
import SwiftUI

struct ToastSurface: View {
    let toasts: Toasts
    let front: Toast
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        let size = toasts.frontSize
        let room = SpotTokens.toastWidest
        let rect = CGRect(x: (room - size.width) / 2 + toasts.frontShift, y: 0, width: size.width, height: size.height)
        let shape = SpotSurfaceShape(rect: rect, radius: SpotTokens.toastRadius)
        ZStack(alignment: .topLeading) {
            SpotCardShadow(shape: shape)
            Color.clear.spotGlass(in: shape)
            ToastView(toast: front)
                .id(front.id)
                .frame(width: front.size.width, alignment: .topLeading)
                .offset(x: rect.minX)
        }
        .frame(width: room, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        .contentShape(shape)
        .onTapGesture { toasts.press(front.id) }
        .allowsHitTesting(isShown)
    }
}
