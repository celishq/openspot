import OpenspotCore
import SwiftUI

/// The handle on the bottom right corner of a card in Edit Spots: a bold arc on its rim, in a colour that stands out from
/// any card, which the person drags to resize the card.
struct SpotResizeHandle: View {
    let size: SpotSize

    var body: some View {
        let radius = SpotTokens.corner(for: size)
        let side = SpotTokens.resizeHandle
        Path { path in
            path.addRelativeArc(
                center: CGPoint(x: side - radius, y: side - radius),
                radius: radius + SpotTokens.resizeHandleGap,
                startAngle: .degrees(10),
                delta: .degrees(70)
            )
        }
        .stroke(SpotTheme.handle, style: StrokeStyle(lineWidth: SpotTokens.resizeHandleLine, lineCap: .round))
        .shadow(color: .black.opacity(SpotTheme.handleShadowStrength), radius: 1)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
    }
}
