import OpenspotCore
import SwiftUI

/// A row drawn by its template: each slot at the frame that its drawing gives it in the place of the row (U8). A control in a
/// slot reports its slot and its value, and the row sends them with its `run` (U9).
struct SpotTemplateRow: View {
    let item: SpotItem
    let template: RowTemplate
    let size: CGSize
    /// The size of the place, such as `2x2`, which picks the template's drawing.
    var place = ""
    let onSlot: (String, String?) -> Void

    var body: some View {
        let parts = template.parts(of: item)
        let frames = RowPlacement(drawing: template.drawing(for: place), parts: parts, size: size).frames
        ZStack(alignment: .topLeading) {
            ForEach(parts, id: \.id) { part in
                if let frame = frames[part.id] {
                    SpotSlotView(part: part, tone: part.kind == "picture" ? item.tone : nil, onSlot: onSlot)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
