import OpenspotCore
import SwiftUI

/// The detail of a text, in the colour of its good, warn or bad tone, or as secondary text with no such tone.
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
