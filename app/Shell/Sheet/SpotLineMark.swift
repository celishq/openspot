import OpenspotCore
import SwiftUI

/// The small mark of a sheet line: a thin ring around its words for a level, or bars for the newest points of a trend,
/// scaled to the highest that shows unless the trend has a top. A tone colours it, and else it is white.
struct SpotLineMark: View {
    let value: MetricValue
    var words: String?

    private static let ringSide: CGFloat = 30
    private static let ringLine: CGFloat = 2

    private var colour: Color {
        value.tone.map(SpotMetricView.colour) ?? SpotTheme.ink
    }

    var body: some View {
        if let words {
            ZStack {
                SpotRing(fill: value.fill, line: Self.ringLine, colour: colour)
                Text(words)
                    .font(SpotType.controlValue)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(Self.ringLine * 2)
            }
            .frame(width: Self.ringSide, height: Self.ringSide)
        } else {
            bars
                .frame(height: SpotMetricView.lineTrendHeight)
                .frame(width: SpotMetricView.edgeMarkWidth)
        }
    }

    private var bars: some View {
        Canvas { context, room in
            let step = SpotMetricView.trendBar + SpotMetricView.trendGap
            let count = Int((room.width + SpotMetricView.trendGap) / step)
            let shown = Array((value.points ?? []).suffix(count))
            let top = value.max ?? shown.max() ?? 0
            let points = shown.map { top > 0 ? min(max($0 / top, 0), 1) : 0 }
            for (index, point) in points.enumerated() {
                let height = max(CGFloat(point) * room.height, SpotMetricView.trendBar)
                let rect = CGRect(
                    x: room.width - CGFloat(points.count - index) * step + SpotMetricView.trendGap,
                    y: room.height - height,
                    width: SpotMetricView.trendBar,
                    height: height
                )
                let opacity = index == points.count - 1 ? 1 : SpotMetricView.oldBar
                context.fill(Path(roundedRect: rect, cornerRadius: SpotMetricView.trendBar / 2), with: .color(colour.opacity(opacity)))
            }
        }
    }
}
