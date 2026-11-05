import OpenspotCore
import SwiftUI

/// The places of a widget, each in the slot its layout gives it, on the same four columns as the grid of spots.
struct SpotWidgetView: View {
    let layout: WidgetLayout
    let places: [String]
    let readings: [String: MetricReading]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(layout.slots.indices, layout.slots)), id: \.0) { index, slot in
                let rect = SpotTokens.placeRect(slot, rows: layout.size.rows)
                SpotMetricView(reading: readings[places[index]], slot: slot, size: rect.size)
                    .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
