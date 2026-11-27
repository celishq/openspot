import OpenspotCore
import SwiftUI

struct PageScrollBar: View {
    let scroll: PageScroll

    var body: some View {
        Rectangle()
            .fill(.bar)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: SpotTheme.settingsBarFade, startPoint: .top, endPoint: .bottom)
                        .frame(height: SpotTokens.settingsBarFade)
                }
            }
            .frame(height: scroll.barHeight + SpotTokens.settingsBarFade)
            .offset(y: -scroll.barHeight)
            .opacity(scroll.isScrolled ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(false)
    }
}
