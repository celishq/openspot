import OpenspotCore
import SwiftUI

/// The dot on a picture that says a row's tone, such as a disk that is almost full. It shows nothing with no tone.
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
