import OpenspotCore
import SwiftUI

/// The places of a widget, each in the cell its drawing gives it.
struct SpotWidgetView: View {
    let layout: WidgetLayout
    let places: [String]
    /// What each script last gave it to draw, read here so that a new reading reruns only this view.
    let reading: (String) -> MetricReading?
    let card: SpotSize

    private var room: CGSize {
        let inset = 2 * SpotTokens.cardPadding(for: card, isWidget: true)
        return CGSize(width: SpotTokens.width(columns: card.columns) - inset, height: SpotTokens.height(rows: card.rows) - inset)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(layout.slots.indices, layout.slots)), id: \.0) { index, slot in
                let rect = layout.rect(of: slot, in: room, gap: SpotTokens.placeGap, sideGap: SpotTokens.sideGap)
                let form = layout.form(of: slot, on: card)
                SpotMetricView(
                    reading: reading(places[index]),
                    form: form,
                    isMirrored: form == .half && slot.x0 > 0,
                    size: rect.size
                )
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
