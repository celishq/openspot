import OpenspotCore
import SwiftUI

struct SpotShine<Content: View>: View {
    let content: Content
    @State private var band = MotionTokens.shineStart

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: SpotTheme.maskInk.opacity(SpotTheme.shineDim), location: 0),
                        .init(color: SpotTheme.maskInk, location: MotionTokens.shineHalf),
                        .init(color: SpotTheme.maskInk.opacity(SpotTheme.shineDim), location: 1),
                    ],
                    startPoint: UnitPoint(x: band - MotionTokens.shineHalf, y: MotionTokens.shineHalf),
                    endPoint: UnitPoint(x: band + MotionTokens.shineHalf, y: MotionTokens.shineHalf)
                )
            }
            .task { withAnimation(SpotMotion.shine) { band = MotionTokens.shineEnd } }
    }
}

extension SpotShine where Content == Text {
    init(words: String, font: Font) {
        self.init { Text(words).font(font) }
    }
}
