import OpenspotCore
import SwiftUI

struct SpotLineMark: View {
    let value: MetricValue
    var words: String?

    private var colour: Color {
        SpotToneWords.colour(of: value.tone) ?? SpotTheme.ink
    }

    var body: some View {
        if let words {
            ZStack {
                SpotRing(fill: value.fill, line: SpotTokens.lineRingLine, colour: colour)
                Text(words)
                    .font(SpotType.controlValue)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(SpotType.leastWordsScale)
                    .padding(SpotTokens.lineRingLine * 2)
            }
            .frame(width: SpotTokens.lineRingSide, height: SpotTokens.lineRingSide)
        } else {
            bars
                .frame(height: SpotTokens.lineTrendHeight)
                .frame(width: SpotTokens.edgeMarkWidth)
        }
    }

    private var bars: some View {
        Canvas { context, room in
            let step = SpotTokens.trendBar + SpotTokens.trendGap
            let count = Int((room.width + SpotTokens.trendGap) / step)
            let shown = Array((value.points ?? []).suffix(count))
            let top = value.max ?? shown.max() ?? 0
            let points = shown.map { top > 0 ? min(max($0 / top, 0), 1) : 0 }
            for (index, point) in points.enumerated() {
                let height = max(CGFloat(point) * room.height, SpotTokens.trendBar)
                let rect = CGRect(
                    x: room.width - CGFloat(points.count - index) * step + SpotTokens.trendGap,
                    y: room.height - height,
                    width: SpotTokens.trendBar,
                    height: height
                )
                let opacity = index == points.count - 1 ? 1 : SpotTheme.oldBar
                context.fill(Path(roundedRect: rect, cornerRadius: SpotTokens.trendBar / 2), with: .color(colour.opacity(opacity)))
            }
        }
    }
}
