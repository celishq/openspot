import OpenspotCore
import SwiftUI

/// How strongly each end of the scroll area fades, from 0 to 1.
struct SpotScrollEdges: Equatable {
    var top = 0.0
    var bottom = 0.0

    static let fadeLength = 56.0

    /// A mask for one end of a scroll area, `fadeLength` long, from that end inwards, for an end that fades this strongly.
    static func end(fading strength: Double, from edge: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .black.opacity(1 - strength), location: 0),
            .init(color: .black.opacity(1 - 0.6 * strength), location: 1.0 / 3),
            .init(color: .black.opacity(1 - 0.2 * strength), location: 2.0 / 3),
            .init(color: .black, location: 1)
        ], startPoint: edge, endPoint: edge == .top ? .bottom : .top)
    }

    /// A mask for cards that scroll in a surface of this height.
    func gradient(height: CGFloat) -> LinearGradient {
        LinearGradient(stops: stops(height: height), startPoint: .top, endPoint: .bottom)
    }

    private func stops(height: CGFloat) -> [Gradient.Stop] {
        let start = (SpotTokens.halo + SpotTokens.rowHeight) / SpotTokens.panelHeight
        let end = (height - SpotTokens.halo - SpotTokens.hintBlock) / SpotTokens.panelHeight
        let length = Self.fadeLength / SpotTokens.panelHeight
        return [
            .init(color: .black.opacity(1 - top), location: start),
            .init(color: .black.opacity(1 - 0.6 * top), location: start + length / 3),
            .init(color: .black.opacity(1 - 0.2 * top), location: start + 2 * length / 3),
            .init(color: .black, location: start + length),
            .init(color: .black, location: end - length),
            .init(color: .black.opacity(1 - 0.2 * bottom), location: end - 2 * length / 3),
            .init(color: .black.opacity(1 - 0.6 * bottom), location: end - length / 3),
            .init(color: .black.opacity(1 - bottom), location: end)
        ]
    }
}

struct SpotScrollEdgeTracker: ViewModifier {
    private static let fadeDistance = 24.0

    @Binding var edges: SpotScrollEdges

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: SpotScrollEdges.self, of: { geometry in
            let below = geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
            return SpotScrollEdges(
                top: min(max(geometry.contentOffset.y / Self.fadeDistance, 0), 1),
                bottom: min(max(below / Self.fadeDistance, 0), 1)
            )
        }, action: { _, new in
            edges = new
        })
    }
}
