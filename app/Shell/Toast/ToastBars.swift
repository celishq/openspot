import OpenspotCore
import SwiftUI

struct ToastBars: View {
    let count: Int

    var body: some View {
        HStack(spacing: SpotTokens.toastBarGap) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(index == 0 ? SpotTheme.ink : SpotTheme.ink.opacity(SpotTheme.track))
                    .frame(width: SpotTokens.toastBarWidth, height: SpotTokens.toastBarHeight)
            }
        }
        .opacity(count > 1 ? 1 : MotionTokens.hiddenOpacity)
    }
}
