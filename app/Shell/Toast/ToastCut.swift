import OpenspotCore
import SwiftUI

struct ToastCut: View {
    let cover: ToastLayout.Cover?
    let width: CGFloat?

    var body: some View {
        let reach = SpotTokens.toastMaxSize.height * CGFloat(Toasts.limit)
        let height = cover?.height ?? 0
        let scale = cover?.scale ?? 1
        let offset = cover?.offset ?? 0
        let wide = height == 0 ? 0 : width ?? 0
        let middle = offset + height - height * scale / 2
        ZStack(alignment: .top) {
            Rectangle()
                .padding(.horizontal, -SpotTokens.toastRoom)
                .padding(.vertical, -reach)
            Rectangle()
                .frame(width: wide * scale, height: reach)
                .offset(y: middle - reach)
                .blendMode(.destinationOut)
            SpotRoundShape(radius: SpotTokens.toastRadius)
                .frame(width: wide, height: height)
                .scaleEffect(scale, anchor: .bottom)
                .offset(y: offset)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}
