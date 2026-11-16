import OpenspotCore
import SwiftUI

struct SpotToneDot: View {
    let tone: MetricValue.Tone?
    let side: CGFloat

    var body: some View {
        if let tone {
            Circle()
                .fill(SpotMetricView.colour(tone))
                .frame(width: max(side / SpotTokens.toneDotParts, SpotTokens.toneDotLeast), height: max(side / SpotTokens.toneDotParts, SpotTokens.toneDotLeast))
                .offset(x: side / SpotTokens.toneDotShiftParts, y: side / SpotTokens.toneDotShiftParts)
        }
    }
}
