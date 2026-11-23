import OpenspotCore
import SwiftUI

struct SpotToneDot: View {
    let tone: MetricValue.Tone?
    let side: CGFloat

    var body: some View {
        if let colour = SpotToneWords.colour(of: tone) {
            Circle()
                .fill(colour)
                .frame(width: max(side / SpotTokens.toneDotParts, SpotTokens.toneDotLeast), height: max(side / SpotTokens.toneDotParts, SpotTokens.toneDotLeast))
                .offset(x: side / SpotTokens.toneDotShiftParts, y: side / SpotTokens.toneDotShiftParts)
        }
    }
}
