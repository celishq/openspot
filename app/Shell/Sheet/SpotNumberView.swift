import OpenspotCore
import SwiftUI

struct SpotNumberView: View {
    @Environment(\.spotIsOnSolid) private var isOnSolid
    let part: SpotPart
    var look: NumberLook = .stat
    let font: Font
    let leastScale: CGFloat
    var alignment: HorizontalAlignment = .leading
    var inset: CGFloat = 0

    private var reading: NumberReading? {
        part.number
    }

    private var colour: Color {
        (SpotToneWords.colour(of: part.tone) ?? SpotTheme.ink(onSolid: isOnSolid)).color
    }

    var body: some View {
        switch look {
        case .ring: ring.padding(inset)
        case .bar: bar.padding(.horizontal, inset)
        case .stat where reading?.isSeries == true: trend.padding(inset)
        case .stat: stat.padding(.horizontal, inset)
        }
    }

    private var stat: some View {
        VStack(alignment: alignment, spacing: SpotType.lineGap) {
            shown
                .font(font)
                .foregroundStyle(SpotTheme.ink(onSolid: isOnSolid))
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
                .foregroundStyle(SpotTheme.ink(onSolid: isOnSolid))
                .lineLimit(1)
                .minimumScaleFactor(leastScale)
            detail
            bars.padding(.top, SpotTokens.placeGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var ring: some View {
        GeometryReader { room in
            let isBig = min(room.size.width, room.size.height) > SpotTokens.wordsRingSide
            let column = min(room.size.width, room.size.height - SpotType.smallLine - SpotType.lineGap)
            Group {
                if isBig {
                    VStack(alignment: .leading, spacing: SpotType.lineGap) {
                        label
                        ringFace(isBig: true)
                    }
                } else if column >= SpotTokens.lineRingSide {
                    VStack(spacing: SpotType.lineGap) {
                        ringFace(isBig: false)
                        label.minimumScaleFactor(SpotType.leastWordsScale)
                    }
                } else {
                    ringFace(isBig: false)
                }
            }
            .frame(width: room.size.width, height: room.size.height)
        }
    }

    private func ringFace(isBig: Bool) -> some View {
        GeometryReader { room in
            let side = min(room.size.width, room.size.height)
            let line = isBig ? SpotTokens.metricBigRingLine : side >= SpotTokens.glyph ? SpotTokens.metricRingLine : SpotTokens.lineRingLine
            ZStack {
                SpotRing(fill: reading?.level ?? 0, line: line, colour: colour)
                VStack(spacing: 0) {
                    shown
                        .font(isBig ? SpotType.ringValue : SpotType.controlValue)
                        .foregroundStyle(SpotTheme.ink(onSolid: isOnSolid))
                        .lineLimit(1)
                        .minimumScaleFactor(SpotType.leastValueScale)
                    if isBig, let detail = part.detail {
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
                    .foregroundStyle(SpotTheme.ink(onSolid: isOnSolid))
                    .lineLimit(1)
                    .minimumScaleFactor(leastScale)
            }
            line(fill: reading?.level ?? 0)
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
                Capsule().fill(SpotTheme.ink(onSolid: isOnSolid).opacity(SpotTheme.track))
                Capsule().fill(colour).frame(width: room.size.width * fill)
            }
        }
        .frame(height: SpotTokens.metricBarLine)
    }

    private var bars: some View {
        SpotTrendBars(points: reading?.scaledPoints ?? [], colour: colour)
    }

    private var shown: Text {
        part.numberPieces.reduce(Text(verbatim: "")) { text, piece in
            let run = Text(verbatim: piece.text)
            return Text("\(text)\(piece.isUnit ? run.foregroundStyle(SpotTheme.ink(onSolid: isOnSolid).opacity(SpotTheme.secondary)) : run)")
        }
    }
}
