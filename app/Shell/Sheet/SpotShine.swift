import OpenspotCore
import SwiftUI

struct SpotShine: View {
    let words: String
    let font: Font
    @State private var band = MotionTokens.shineStart
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotMoves) private var moves

    var body: some View {
        Text(words)
            .font(font)
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
            .task(id: isShown && moves) {
                if isShown && moves {
                    withAnimation(SpotMotion.shine) { band = MotionTokens.shineEnd }
                } else {
                    withTransaction(Transaction(animation: nil)) { band = MotionTokens.shineStart }
                }
            }
    }
}
