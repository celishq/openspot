import OpenspotCore
import SwiftUI

struct SpotNumberView: View {
    let part: SpotPart
    var look: NumberLook = .stat
    let font: Font
    let leastScale: CGFloat
    var alignment: HorizontalAlignment = .leading

    private var reading: NumberReading? {
        part.number
    }

    private var colour: Color {
        SpotToneWords.colour(of: part.tone) ?? SpotTheme.ink
    }

    var body: some View {
        switch look {
        case .ring: ring
        case .bar: bar
        case .stat where reading?.isSeries == true: trend
        case .stat: stat
        }
    }

    private var stat: some View {
        VStack(alignment: alignment, spacing: SpotType.lineGap) {
            shown
                .font(font)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(leastScale)
            if let title = part.title {
                Text(title).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
            }
        }
        .modifier(SpotColorBar(color: part.color))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
            shown
                .font(SpotType.metric)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(leastScale)
            detail
            bars.padding(.top, SpotTokens.placeGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var ring: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
            GeometryReader { room in
                let side = min(room.size.width, room.size.height)
                let line = side > SpotTokens.wordsRingSide ? SpotTokens.metricBigRingLine : SpotTokens.metricRingLine
                ZStack {
                    SpotRing(fill: reading?.fill ?? 0, line: line, colour: colour)
                    VStack(spacing: 0) {
                        shown
                            .font(side > SpotTokens.wordsRingSide ? SpotType.ringValue : SpotType.controlValue)
                            .foregroundStyle(SpotTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(SpotType.leastValueScale)
                        if side > SpotTokens.wordsRingSide, let detail = part.detail {
                            Text(detail)
                                .font(SpotType.small)
                                .modifier(SpotSecondaryText())
                                .lineLimit(1)
                                .minimumScaleFactor(SpotType.leastWordsScale)
                        }
                    }
                    .padding(line / 2 + line + SpotTokens.ringInsideGap)
                }
                .frame(width: side, height: side)
                .frame(width: room.size.width, height: room.size.height)
            }
        }
    }

    private var bar: some View {
        ViewThatFits(in: .vertical) {
            if part.detail != nil {
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    barLine
                    detail
                }
            }
            barLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var barLine: some View {
        VStack(alignment: .leading, spacing: SpotType.barLineGap) {
            HStack(alignment: .firstTextBaseline, spacing: SpotTokens.placeGap) {
                label
                Spacer(minLength: 0)
                shown
                    .font(SpotType.value)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(leastScale)
            }
            if reading?.isSeries == true {
                bars.frame(height: SpotTokens.lineTrendHeight)
            } else {
                line(fill: reading?.fill ?? 0)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if let title = part.title {
            Text(title)
                .font(SpotType.small)
                .modifier(SpotSecondaryText())
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let detail = part.detail {
            SpotToneWords(text: detail, tone: part.tone)
        }
    }

    private func line(fill: Double) -> some View {
        GeometryReader { room in
            ZStack(alignment: .leading) {
                Capsule().fill(SpotTheme.ink.opacity(SpotTheme.track))
                Capsule().fill(colour).frame(width: room.size.width * fill)
            }
        }
        .frame(height: SpotTokens.metricBarLine)
    }

    private var bars: some View {
        Canvas { context, room in
            let step = SpotTokens.trendBar + SpotTokens.trendGap
            let count = Int((room.width + SpotTokens.trendGap) / step)
            let points = Array((reading?.scaledPoints ?? []).suffix(count))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shown: Text {
        part.numberPieces.reduce(Text(verbatim: "")) { text, piece in
            let run = Text(verbatim: piece.text)
            return Text("\(text)\(piece.isUnit ? run.foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary)) : run)")
        }
    }
}
