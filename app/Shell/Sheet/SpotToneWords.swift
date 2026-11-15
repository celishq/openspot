import OpenspotCore
import SwiftUI

struct SpotToneWords: View {
    let text: String
    let tone: MetricValue.Tone?

    var body: some View {
        if let colour = Self.colour(of: tone) {
            Text(text).font(SpotType.detail).foregroundStyle(colour).lineLimit(1)
        } else {
            Text(text).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
        }
    }

    static func colour(of tone: MetricValue.Tone?) -> Color? {
        tone.map(SpotMetricView.colour)
    }
}
