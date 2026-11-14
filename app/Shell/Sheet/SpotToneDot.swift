import OpenspotCore
import SwiftUI

struct SpotToneDot: View {
    let tone: MetricValue.Tone?
    let side: CGFloat

    var body: some View {
        if let tone {
            Circle()
                .fill(SpotMetricView.colour(tone))
                .frame(width: max(side / 4, 5), height: max(side / 4, 5))
                .offset(x: side / 12, y: side / 12)
        }
    }
}
