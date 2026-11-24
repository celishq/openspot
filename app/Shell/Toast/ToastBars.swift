import OpenspotCore
import SwiftUI

struct ToastBars: View {
    let count: Int

    var body: some View {
        let bar = SpotTokens.toastBar(count)
        HStack(spacing: bar.gap) {
            ForEach(0..<count, id: \.self) { index in
                Color.clear
                    .frame(width: bar.width, height: SpotTokens.toastBarHeight)
                    .modifier(SpotGlass(shape: SpotRoundShape(radius: SpotTokens.toastBarHeight / 2)))
                    .opacity(index == 0 ? 1 : SpotTheme.track)
            }
        }
        .frame(height: SpotTokens.toastBarHeight)
    }
}
