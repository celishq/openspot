import OpenspotCore
import SwiftUI

struct SpotRowNumber: View {
    let number: NumberReading
    let tone: MetricValue.Tone?

    private var colour: Color {
        SpotToneWords.colour(of: tone) ?? SpotTheme.ink
    }

    var body: some View {
        if number.look == .ring, let fill = number.fill {
            ZStack {
                SpotRing(fill: fill, line: SpotTokens.lineRingLine, colour: colour)
                Text(number.bare)
                    .font(SpotType.controlValue)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(SpotType.leastWordsScale)
                    .padding(SpotTokens.lineRingLine * 2)
            }
            .frame(width: SpotTokens.lineRingSide, height: SpotTokens.lineRingSide)
        } else if number.isSeries {
            SpotTrendBars(points: number.scaledPoints, colour: colour)
                .frame(width: SpotTokens.edgeMarkWidth, height: SpotTokens.lineTrendHeight)
        } else {
            Text(number.text)
                .font(SpotType.value)
                .foregroundStyle(colour)
                .lineLimit(1)
        }
    }
}
