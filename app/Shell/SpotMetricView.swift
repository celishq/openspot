import OpenspotCore
import SwiftUI

/// One place of a widget: a mark, then a title with a detail. A wide place puts them side by side, a tall one stacks
/// them, and a narrow one keeps only what fits. A stale value stays, and dims.
struct SpotMetricView: View {
    let reading: MetricReading?
    let slot: WidgetLayout.Slot
    let size: CGSize

    private static let bigRing: CGFloat = 64
    private static let ringLine: CGFloat = 4
    private static let trendLine: CGFloat = 1.5
    private static let dot: CGFloat = 7
    private static let rowLine: CGFloat = 17
    private static let shortPlace: CGFloat = 40

    private var isTall: Bool { slot.rows > 1 }
    private var isNarrow: Bool { slot.columns == 1 }
    private var value: MetricValue? { reading?.value }
    private var title: String { value?.title ?? "–" }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .opacity(reading?.isStale == true ? 0.5 : 1)
    }

    @ViewBuilder
    private var content: some View {
        switch reading?.kind ?? .value {
        case .rows: rows
        case .gauge: gauge
        case .trend: trend
        case .status: placed(mark: dot(value?.tone))
        case .value: placed(mark: symbol)
        }
    }

    private func placed(mark: some View) -> some View {
        Group {
            if isTall {
                VStack(alignment: .leading, spacing: 0) {
                    mark
                    Spacer(minLength: 0)
                    text(titleFont: SpotType.metric)
                }
            } else if isNarrow {
                HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap / 2) {
                    if reading?.kind == .status { mark }
                    text(titleFont: SpotType.title)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: SpotTokens.placeGap) {
                    mark
                    text(titleFont: SpotType.title)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func text(titleFont: Font, showsDetail: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .lineLimit(1)
            if showsDetail, let detail = value?.detail {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var symbol: some View {
        if let name = value?.symbol {
            Image(systemName: name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(colour(value?.tone))
        }
    }

    private func dot(_ tone: MetricValue.Tone?) -> some View {
        Circle()
            .fill(colour(tone))
            .frame(width: Self.dot, height: Self.dot)
    }

    private func colour(_ tone: MetricValue.Tone?) -> Color {
        switch tone {
        case .good: .green
        case .warn: .orange
        case .bad: .red
        case nil: .white
        }
    }

    @ViewBuilder
    private var gauge: some View {
        if isTall {
            VStack(spacing: SpotTokens.placeGap) {
                ring(Self.bigRing) {
                    Text(title).font(SpotType.title).foregroundStyle(.white.opacity(SpotTokens.titleOpacity)).lineLimit(1)
                }
                if let detail = value?.detail {
                    Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isNarrow {
            ring(min(size.width, size.height)) {
                Text(title).font(SpotType.small).foregroundStyle(.white.opacity(SpotTokens.titleOpacity)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: SpotTokens.placeGap) {
                ring(min(size.height, SpotTokens.glyphSize)) {
                    if let name = value?.symbol {
                        Image(systemName: name).font(SpotType.small).foregroundStyle(.white)
                    }
                }
                text(titleFont: SpotType.title)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func ring(_ side: CGFloat, @ViewBuilder inside: () -> some View) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: Self.ringLine)
            Circle()
                .trim(from: 0, to: value?.fill ?? 0)
                .rotation(.degrees(-90))
                .stroke(colour(value?.tone), style: StrokeStyle(lineWidth: Self.ringLine, lineCap: .round))
            inside().padding(Self.ringLine)
        }
        .padding(Self.ringLine / 2)
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private var trend: some View {
        if isTall || isNarrow {
            VStack(alignment: .leading, spacing: SpotTokens.placeGap / 2) {
                text(titleFont: isTall ? SpotType.metric : SpotType.title, showsDetail: isTall || size.height > Self.shortPlace)
                line
            }
        } else {
            HStack(spacing: SpotTokens.placeGap) {
                text(titleFont: SpotType.title)
                line
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var line: some View {
        Canvas { context, size in
            let points = value?.scaledPoints ?? []
            guard points.count > 1 else { return }
            let inset = Self.trendLine
            var path = Path()
            for (index, point) in points.enumerated() {
                let spot = CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(points.count - 1),
                    y: inset + (size.height - 2 * inset) * CGFloat(1 - point)
                )
                if index == 0 { path.move(to: spot) } else { path.addLine(to: spot) }
            }
            context.stroke(path, with: .color(colour(value?.tone)), style: StrokeStyle(lineWidth: Self.trendLine, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SpotType.title)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .lineLimit(1)
                .frame(height: Self.rowLine, alignment: .leading)
            ForEach(Array((value?.rows ?? []).prefix(rowRoom).enumerated()), id: \.offset) { _, row in
                HStack(spacing: SpotTokens.placeGap / 2) {
                    if row.tone != nil { dot(row.tone) }
                    Text(row.title)
                        .font(SpotType.detail)
                        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let detail = row.detail {
                        Text(detail)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                            .lineLimit(1)
                    }
                }
                .frame(height: Self.rowLine)
            }
        }
        .frame(maxHeight: .infinity, alignment: isTall ? .top : .center)
    }

    private var rowRoom: Int {
        max(Int(size.height / Self.rowLine) - 1, 0)
    }
}
