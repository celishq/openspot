import OpenspotCore
import SwiftUI

struct SpotCardDrawing: View {
    let layout: WidgetLayout
    let face: CardFace
    let card: SpotSize
    var view: (CGSize) -> SpotCustomView? = { _ in nil }
    let onSlot: (String, String?) -> Void

    private var room: CGSize {
        let inset = 2 * SpotTokens.cardPadding(for: card, isWidget: true)
        return CGSize(width: SpotTokens.width(columns: card.columns) - inset, height: SpotTokens.height(rows: card.rows) - inset)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(layout.names, layout.slots)), id: \.0) { id, slot in
                if let part = face.parts.first(where: { $0.id == id }) {
                    let rect = layout.rect(of: slot, in: room, gap: SpotTokens.placeGap, sideGap: SpotTokens.sideGap)
                    Group {
                        if part.kind == "view" {
                            view(rect.size)
                        } else {
                            SpotSlotView(part: part, tone: part.tone, height: rect.height, onSlot: onSlot)
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
