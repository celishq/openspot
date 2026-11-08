import OpenspotCore
import SwiftUI

/// A card that its script draws: each component in the area that the card's drawing gives it (U5). A control acts at once,
/// and a press anywhere else works as on any card.
struct SpotCardDrawing: View {
    let drawing: [[String]]
    let face: CardFace
    let card: SpotSize
    /// The last value of each script, which a `spot` component draws.
    var readings: [String: MetricReading] = [:]
    /// The plugin's own view at the size of its area, once it is built (V3).
    var view: (CGSize) -> SpotCustomView? = { _ in nil }
    let onSlot: (String, String?) -> Void

    private var room: CGSize {
        let inset = 2 * SpotTokens.cardPadding(for: card, isWidget: true)
        return CGSize(width: SpotTokens.width(columns: card.columns) - inset, height: SpotTokens.height(rows: card.rows) - inset)
    }

    var body: some View {
        let layout = WidgetLayout(drawing: drawing.map { $0.joined(separator: " ") }, size: card)
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(layout.letters, layout.slots)), id: \.0) { id, slot in
                if let part = face.parts.first(where: { $0.id == id }) {
                    let rect = layout.rect(of: slot, in: room, gap: SpotTokens.placeGap, sideGap: SpotTokens.sideGap)
                    Group {
                        if part.kind == "view" {
                            view(rect.size)
                        } else if part.kind == "spot" {
                            SpotMetricView(reading: readings[part.id], form: layout.form(of: slot, on: card), isMirrored: false, size: rect.size)
                        } else {
                            SpotSlotView(part: part, tone: part.tone, onSlot: onSlot)
                        }
                    }
                    .frame(width: rect.width, height: rect.height, alignment: .leading)
                    .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
