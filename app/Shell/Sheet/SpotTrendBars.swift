import OpenspotCore
import SwiftUI

struct SpotTrendBars: View {
    let points: [Double]
    let colour: Color

    var body: some View {
        Canvas { context, room in
            let step = SpotTokens.trendBar + SpotTokens.trendGap
            let count = Int((room.width + SpotTokens.trendGap) / step)
            let shown = Array(points.suffix(count))
            for (index, point) in shown.enumerated() {
                let height = max(CGFloat(point) * room.height, SpotTokens.trendBar)
                let rect = CGRect(
                    x: room.width - CGFloat(shown.count - index) * step + SpotTokens.trendGap,
                    y: room.height - height,
                    width: SpotTokens.trendBar,
                    height: height
                )
                let opacity = index == shown.count - 1 ? 1 : SpotTheme.oldBar
                context.fill(Path(roundedRect: rect, cornerRadius: SpotTokens.trendBar / 2), with: .color(colour.opacity(opacity)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
