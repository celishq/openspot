import OpenspotCore
import SwiftUI

/// The handle on the bottom right corner of a card in Edit Spots: a bold stretch of the card's own rim at that corner, over
/// its ring, in the colour of text. It lies in a square on the corner, so that it moves with the corner as the card
/// resizes. It takes no press; the corner of the card takes the drag.
struct SpotResizeHandle: View {
    let size: SpotSize
    @MainActor private static var rims: [String: Path] = [:]

    var body: some View {
        Self.rim(of: size)
            .stroke(SpotTheme.ink, style: StrokeStyle(lineWidth: SpotTokens.resizeHandleLine, lineCap: .round))
            .frame(width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
            .allowsHitTesting(false)
    }

    /// The stretch of a card's rim at its bottom right corner, between 10° and 53° around the centre of that corner, nearer
    /// the right edge than the bottom, in the square on that corner. It is found once for each size.
    private static func rim(of size: SpotSize) -> Path {
        if let rim = rims[size.name] { return rim }
        let radius = SpotTokens.corner(for: size)
        let card = CGRect(x: 0, y: 0, width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let edge = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: card)
        let centre = CGPoint(x: card.maxX - radius, y: card.maxY - radius)
        let steps = 720
        let corner = (0...steps).map { Double($0) / Double(steps) }.filter { share in
            let point = edge.trimmedPath(from: 0, to: share).currentPoint ?? .zero
            let angle = atan2(point.y - centre.y, point.x - centre.x) * 180 / .pi
            return point.x >= centre.x && point.y >= centre.y && (10...53).contains(angle)
        }
        let side = SpotTokens.resizeHandle
        let rim = edge.trimmedPath(from: corner.first ?? 0, to: corner.last ?? 0)
            .offsetBy(dx: side - card.width, dy: side - card.height)
        rims[size.name] = rim
        return rim
    }
}
