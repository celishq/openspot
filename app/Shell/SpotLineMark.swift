import OpenspotCore
import SwiftUI

/// The small mark of a sheet line, in the sizes of a widget's marks: a bar for a gauge, or bars for the newest points of a
/// trend, scaled to the highest that shows unless the trend has a top. A tone colours it, and else it is white.
struct SpotLineMark: View {
    let value: MetricValue

    private var colour: Color {
        value.tone.map(SpotMetricView.colour) ?? SpotTheme.ink
    }

    var body: some View {
        Group {
            if value.kind == .trend {
                bars.frame(height: SpotMetricView.lineTrendHeight)
            } else {
                bar
            }
        }
        .frame(width: SpotMetricView.edgeMarkWidth)
    }

    private var bar: some View {
        GeometryReader { room in
            ZStack(alignment: .leading) {
                Capsule().fill(SpotTheme.ink.opacity(SpotTheme.track))
                Capsule().fill(colour).frame(width: room.size.width * value.fill)
            }
        }
        .frame(height: SpotMetricView.barLine)
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
