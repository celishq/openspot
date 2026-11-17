import OpenspotCore
import SwiftUI

struct SpotMetricView: View {
    let reading: MetricReading?
    let form: WidgetLayout.Form
    let isMirrored: Bool
    let size: CGSize

    private var kind: MetricKind { reading?.kind ?? .value }
    private var value: MetricValue? { reading?.value }
    private var title: String { value?.title ?? "–" }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .opacity(reading?.isStale == true ? SpotTheme.stale : 1)
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
        VStack(alignment: .leading, spacing: SpotType.barLineGap) {
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
                    bars.frame(height: SpotTokens.lineTrendHeight)
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
                ring(side: min(size.width, size.height), line: SpotTokens.metricRingLine) {
                    Text(title)
                        .font(SpotType.controlValue)
                        .foregroundStyle(SpotTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(SpotType.leastWordsScale)
                }
            case .trend:
                VStack(spacing: SpotType.lineGap) {
                    valueText(SpotType.controlValue)
                    bars.frame(width: SpotTokens.metricControlBars.width, height: SpotTokens.metricControlBars.height)
                }
            case .value, .status, .rows:
                VStack(spacing: SpotType.lineGap) {
                    symbol
                    valueText(reading?.symbol == nil ? SpotType.value : SpotType.controlValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var edgeMark: some View {
        switch kind {
        case .gauge:
            ring(side: min(size.height, SpotTokens.glyph), line: SpotTokens.metricRingLine) { ringSymbol }
        case .trend:
            bars.frame(width: SpotTokens.edgeMarkWidth)
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
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(SpotType.leastValueScale)
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
        if let name = reading?.symbol {
            Image(systemName: name)
                .font(SpotType.glyph)
                .foregroundStyle(markColour)
        }
    }

    @ViewBuilder
    private var ringSymbol: some View {
        if let name = reading?.symbol {
            Image(systemName: name)
                .font(SpotType.small)
                .foregroundStyle(SpotTheme.ink)
        }
    }

    private func dot(_ colour: Color) -> some View {
        Circle()
            .fill(colour)
            .frame(width: SpotTokens.toneDot, height: SpotTokens.toneDot)
    }

    private var markColour: Color {
        value?.tone.map(Self.colour) ?? SpotTheme.ink
    }

    private var bigRing: some View {
        ring(side: min(size.width, size.height - SpotTokens.placeGap * 2), line: SpotTokens.metricBigRingLine) {
            VStack(spacing: 0) {
                Text(title)
                    .font(SpotType.ringValue)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(SpotType.leastValueScale)
                if let detail = value?.detail {
                    Text(detail)
                        .font(SpotType.small)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                        .minimumScaleFactor(SpotType.leastWordsScale)
                }
            }
        }
    }

    private func ring(side: CGFloat, line: CGFloat, @ViewBuilder inside: () -> some View) -> some View {
        ZStack {
            SpotRing(fill: value?.fill ?? 0, line: line, colour: markColour)
            inside().padding(line / 2 + line + SpotTokens.ringInsideGap)
        }
        .frame(width: side, height: side)
    }

    private func bar(fill: Double) -> some View {
        GeometryReader { room in
            ZStack(alignment: .leading) {
                Capsule().fill(SpotTheme.ink.opacity(SpotTheme.track))
                Capsule().fill(markColour).frame(width: room.size.width * fill)
            }
        }
        .frame(height: SpotTokens.metricBarLine)
    }

    private var bars: some View {
        Canvas { context, room in
            let step = SpotTokens.trendBar + SpotTokens.trendGap
            let count = Int((room.width + SpotTokens.trendGap) / step)
            let points = Array((value?.scaledPoints ?? []).suffix(count))
            for (index, point) in points.enumerated() {
                let height = max(CGFloat(point) * room.height, SpotTokens.trendBar)
                let rect = CGRect(
                    x: room.width - CGFloat(points.count - index) * step + SpotTokens.trendGap,
                    y: room.height - height,
                    width: SpotTokens.trendBar,
                    height: height
                )
                let isNewest = index == points.count - 1
                context.fill(
                    Path(roundedRect: rect, cornerRadius: SpotTokens.trendBar / 2),
                    with: .color(markColour.opacity(isNewest ? 1 : SpotTheme.oldBar))
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
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
            }
            .padding(.bottom, SpotTokens.metricTitleGap)
            ForEach(Array((value?.rows ?? []).prefix(rowRoom).enumerated()), id: \.offset) { _, row in
                HStack(spacing: SpotTokens.placeGap / 2) {
                    if let tone = row.tone { dot(Self.colour(tone)) }
                    Text(row.title)
                        .font(SpotType.detail)
                        .foregroundStyle(SpotTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let detail = row.detail {
                        Text(detail)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                            .lineLimit(1)
                    }
                }
                .frame(height: SpotTokens.metricRowLine)
            }
        }
    }

    static func colour(_ tone: MetricValue.Tone) -> Color {
        switch tone {
        case .good: SpotTheme.good
        case .warn: SpotTheme.warn
        case .bad: SpotTheme.bad
        }
    }

    private var rowRoom: Int {
        max(Int(size.height / SpotTokens.metricRowLine) - 2, 0)
    }
}
