import OpenspotCore
import SwiftUI

/// The places of a widget, each in the slot its layout gives it. A single place fills the card.
struct SpotWidgetView: View {
    let layout: WidgetLayout
    let places: [String]
    let readings: [String: MetricReading]
    let card: SpotSize

    private var room: CGSize {
        let inset = 2 * SpotTokens.cardPadding(for: card, isWidget: true)
        return CGSize(width: SpotTokens.width(columns: card.columns) - inset, height: SpotTokens.height(rows: card.rows) - inset)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(layout.slots.indices, layout.slots)), id: \.0) { index, slot in
                let rect = layout == .single ? CGRect(origin: .zero, size: room) : SpotTokens.placeRect(slot, rows: layout.rows, room: room)
                SpotMetricView(
                    reading: readings[places[index]],
                    form: layout.form(of: slot, on: card),
                    isMirrored: slot.form == .half && slot.column > 0,
                    size: rect.size
                )
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
