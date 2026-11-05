import OpenspotCore
import SwiftUI

/// One place of a widget, drawn in the form its layout gives. A big place leads with one large value, a line lies
/// between a label and a value, a half hugs its outer edge, and a stat or a control keeps only the value and what fits.
/// A stale value stays, and dims.
struct SpotMetricView: View {
    let reading: MetricReading?
    let form: WidgetLayout.Form
    let isMirrored: Bool
    let size: CGSize

    private static let bigRingLine: CGFloat = 8
    private static let smallRingLine: CGFloat = 4
    private static let barLine: CGFloat = 4
    private static let trendBar: CGFloat = 3
    private static let trendGap: CGFloat = 2
    private static let oldBar = 0.55
    private static let dot: CGFloat = 7
    private static let rowLine: CGFloat = 15
    private static let edgeMarkWidth: CGFloat = 44
    private static let lineTrendHeight: CGFloat = 12

    private var kind: MetricKind { reading?.kind ?? .value }
    private var value: MetricValue? { reading?.value }
    private var title: String { value?.title ?? "–" }
    private var tint: Color? { reading?.tint.map(Self.colour) }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .opacity(reading?.isStale == true ? 0.5 : 1)
    }

    @ViewBuilder
    private var content: some View {
        switch form {
        case .big: big
        case .line: line
        case .half: half
        case .stat: stat
        case .control: control
        }
    }

    @ViewBuilder
    private var big: some View {
        switch kind {
        case .rows:
            rows
        case .gauge:
            VStack(alignment: .leading, spacing: 0) {
                label
                bigRing.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .trend:
            VStack(alignment: .leading, spacing: 0) {
                label
                valueText(SpotType.metric)
                detail
                bars.padding(.top, SpotTokens.placeGap)
            }
        case .value, .status:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    label
                    Spacer(minLength: 0)
                    symbol
                }
                Spacer(minLength: 0)
                valueText(SpotType.metric)
                detail
            }
        }
    }

    private var line: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap + 2) {
            HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap) {
                label
                Spacer(minLength: 0)
                valueText(SpotType.value)
            }
            if kind == .gauge {
                bar(fill: value?.fill ?? 0)
            } else if kind == .trend {
                if value?.max != nil {
                    bar(fill: value?.scaledPoints.last ?? 0)
                } else {
                    bars.frame(height: Self.lineTrendHeight)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var half: some View {
        HStack(spacing: SpotTokens.placeGap) {
            if !isMirrored {
                edgeMark
            }
            VStack(alignment: isMirrored ? .trailing : .leading, spacing: SpotType.lineGap) {
                label
                valueText(SpotType.value)
            }
            .frame(maxWidth: .infinity, alignment: isMirrored ? .trailing : .leading)
            if isMirrored {
                edgeMark
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var stat: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            valueText(SpotType.value)
            label
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var control: some View {
        Group {
            switch kind {
            case .gauge:
                ring(side: min(size.width, size.height), line: Self.smallRingLine) {
                    Text(title)
                        .font(SpotType.controlValue)
                        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            case .trend:
                VStack(spacing: SpotType.lineGap) {
                    valueText(SpotType.controlValue)
                    bars
                }
            case .value, .status, .rows:
                VStack(spacing: SpotType.lineGap) {
                    symbol
                    valueText(value?.symbol == nil ? SpotType.value : SpotType.controlValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var edgeMark: some View {
        switch kind {
        case .gauge:
            ring(side: min(size.height, SpotTokens.glyphSize), line: Self.smallRingLine) { ringSymbol }
        case .trend:
            bars.frame(width: Self.edgeMarkWidth)
        case .value:
            symbol
        case .rows, .status:
            EmptyView()
        }
    }

    private var label: some View {
        Text(reading?.label ?? "")
            .font(SpotType.small)
            .modifier(SpotSecondaryText())
            .lineLimit(1)
    }

    private func valueText(_ font: Font) -> some View {
        HStack(alignment: .center, spacing: SpotTokens.placeGap / 2) {
            if kind == .status { dot(markColour) }
            Text(title)
                .font(font)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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
    private var symbol: some View {
        if let name = value?.symbol {
            Image(systemName: name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(markColour)
        }
    }

    @ViewBuilder
    private var ringSymbol: some View {
        if let name = value?.symbol {
            Image(systemName: name)
                .font(SpotType.small)
                .foregroundStyle(.white)
        }
    }

    private func dot(_ colour: Color) -> some View {
        Circle()
            .fill(colour)
            .frame(width: Self.dot, height: Self.dot)
    }

    /// The colour of a mark: what its tone means, or else its tint, or else white.
    private var markColour: Color {
        value?.tone.map(Self.colour) ?? tint ?? .white
    }

    private static func colour(_ tint: MetricTint) -> Color {
        switch tint {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        }
    }

    private var bigRing: some View {
        ring(side: min(size.width, size.height - SpotTokens.placeGap * 2), line: Self.bigRingLine) {
            VStack(spacing: 0) {
                Text(title)
                    .font(SpotType.ringValue)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let detail = value?.detail {
                    Text(detail)
                        .font(SpotType.small)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private func ring(side: CGFloat, line: CGFloat, @ViewBuilder inside: () -> some View) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(SpotTokens.track), lineWidth: line)
            Circle()
                .trim(from: 0, to: value?.fill ?? 0)
                .rotation(.degrees(-90))
                .stroke(markColour, style: StrokeStyle(lineWidth: line, lineCap: .round))
            inside().padding(line + 2)
        }
        .padding(line / 2)
        .frame(width: side, height: side)
    }

    private func bar(fill: Double) -> some View {
        GeometryReader { room in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(SpotTokens.track))
                Capsule().fill(markColour).frame(width: room.size.width * fill)
            }
        }
        .frame(height: Self.barLine)
    }

    private var bars: some View {
        Canvas { context, room in
            let step = Self.trendBar + Self.trendGap
            let count = Int((room.width + Self.trendGap) / step)
            let points = Array((value?.scaledPoints ?? []).suffix(count))
            for (index, point) in points.enumerated() {
                let height = max(CGFloat(point) * room.height, Self.trendBar)
                let rect = CGRect(
                    x: room.width - CGFloat(points.count - index) * step + Self.trendGap,
                    y: room.height - height,
                    width: Self.trendBar,
                    height: height
                )
                let isNewest = index == points.count - 1
                context.fill(
                    Path(roundedRect: rect, cornerRadius: Self.trendBar / 2),
                    with: .color(markColour.opacity(isNewest ? 1 : Self.oldBar))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap) {
                label
                Spacer(minLength: 0)
                Text(title)
                    .font(SpotType.value)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
            }
            .padding(.bottom, 4)
            ForEach(Array((value?.rows ?? []).prefix(rowRoom).enumerated()), id: \.offset) { _, row in
                HStack(spacing: SpotTokens.placeGap / 2) {
                    if let tone = row.tone { dot(Self.colour(tone)) }
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
    }

    private static func colour(_ tone: MetricValue.Tone) -> Color {
        switch tone {
        case .good: .green
        case .warn: .orange
        case .bad: .red
        }
    }

    private var rowRoom: Int {
        max(Int(size.height / Self.rowLine) - 2, 0)
    }
}
