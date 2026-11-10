import OpenspotCore
import SwiftUI

/// The handle on the bottom right corner of a card in Edit Spots: a short arc just outside its rim, which the person drags
/// to resize the card.
struct SpotResizeHandle: View {
    let size: SpotSize

    var body: some View {
        let radius = SpotTokens.corner(for: size)
        let side = SpotTokens.resizeHandle
        Path { path in
            path.addRelativeArc(
                center: CGPoint(x: side - radius, y: side - radius),
                radius: radius + SpotTokens.resizeHandleGap,
                startAngle: .degrees(15),
                delta: .degrees(60)
            )
        }
        .stroke(SpotTheme.ink.opacity(SpotTheme.handleStrength), style: StrokeStyle(lineWidth: SpotTokens.resizeHandleLine, lineCap: .round))
        .frame(width: side, height: side)
        .contentShape(Rectangle())
    }
}
