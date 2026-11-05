import OpenspotCore
import SwiftUI

/// One place of a widget, by one rule: the label of the metric, then its value with a detail, and a mark beside or
/// under them. A place keeps only what fits. A stale value stays, and dims.
struct SpotMetricView: View {
    let reading: MetricReading?
    let slot: WidgetLayout.Slot
    let size: CGSize

    private static let bigRing: CGFloat = 52
    private static let ringLine: CGFloat = 4
    private static let barLine: CGFloat = 3
    private static let trendLine: CGFloat = 1.5
    private static let dot: CGFloat = 7
    private static let rowLine: CGFloat = 15
    private static let shortPlace: CGFloat = 40

    private var isTall: Bool { slot.rows > 1 }
    private var isNarrow: Bool { slot.columns == 1 }
    private var isShort: Bool { size.height < Self.shortPlace }
    private var kind: MetricKind { reading?.kind ?? .value }
    private var value: MetricValue? { reading?.value }
    private var title: String { value?.title ?? "–" }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .opacity(reading?.isStale == true ? 0.5 : 1)
    }

    @ViewBuilder
    private var content: some View {
        if kind == .rows {
            rows
        } else if isTall {
            tall
        } else if isNarrow {
            narrow
        } else {
            wide
        }
    }

    private var tall: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                label
                Spacer(minLength: 0)
                sideMark(side: Self.bigRing)
            }
            if kind == .trend {
                line.padding(.vertical, SpotTokens.placeGap / 2)
            } else {
                Spacer(minLength: 0)
            }
            reading(font: SpotType.metric)
            detail
        }
    }

    private var wide: some View {
        HStack(spacing: SpotTokens.placeGap) {
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                label
                HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap / 2) {
                    reading(font: SpotType.title).layoutPriority(1)
                    detail
                }
            }
            .layoutPriority(1)
            if kind == .trend {
                line
            } else {
                Spacer(minLength: 0)
                sideMark(side: min(size.height, SpotTokens.glyphSize))
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var narrow: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            label
            reading(font: SpotType.title)
            if !isShort {
                if kind == .gauge {
                    bar.padding(.top, SpotTokens.placeGap / 2)
                } else if kind == .trend {
                    line
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: isShort ? .center : .top)
    }

    private var label: some View {
        Text(reading?.label ?? "")
            .font(SpotType.small)
            .modifier(SpotSecondaryText())
            .lineLimit(1)
    }

    private func reading(font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap / 2) {
            if kind == .status { dot(value?.tone) }
            Text(title)
                .font(font)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let detail = value?.detail {
            Text(detail)
                .font(SpotType.detail)
                .modifier(SpotSecondaryText())
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func sideMark(side: CGFloat) -> some View {
        switch kind {
        case .gauge:
            ring(side)
        case .value:
            if let name = value?.symbol {
                Image(systemName: name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colour(value?.tone))
            }
        case .trend, .rows, .status:
            EmptyView()
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

    private func ring(_ side: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: Self.ringLine)
            Circle()
                .trim(from: 0, to: value?.fill ?? 0)
                .rotation(.degrees(-90))
                .stroke(colour(value?.tone), style: StrokeStyle(lineWidth: Self.ringLine, lineCap: .round))
            if let name = value?.symbol {
                Image(systemName: name)
                    .font(SpotType.small)
                    .foregroundStyle(.white)
                    .padding(Self.ringLine)
            }
        }
        .padding(Self.ringLine / 2)
        .frame(width: side, height: side)
    }

    private var bar: some View {
        GeometryReader { room in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(colour(value?.tone)).frame(width: room.size.width * (value?.fill ?? 0))
            }
        }
        .frame(height: Self.barLine)
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
            HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap) {
                label
                Spacer(minLength: 0)
                Text(title)
                    .font(SpotType.small)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
            }
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
        isNarrow ? 0 : max(Int(size.height / Self.rowLine) - 1, 0)
    }
}
