import OpenspotCore
import SwiftUI

/// How strongly each end of the scroll area fades, from 0 to 1.
struct SpotScrollEdges: Equatable {
    var top = 0.0
    var bottom = 0.0

    static let fadeLength = 56.0

    /// A mask for cards that scroll in a surface of this height, over a view of the `whole` height.
    func gradient(height: CGFloat, whole: CGFloat = SpotTokens.panelHeight) -> LinearGradient {
        LinearGradient(stops: stops(height: height, whole: whole), startPoint: .top, endPoint: .bottom)
    }

    private func stops(height: CGFloat, whole: CGFloat) -> [Gradient.Stop] {
        let start = (SpotTokens.halo + SpotTokens.rowHeight) / whole
        let end = (height - SpotTokens.halo - SpotTokens.hintBlock) / whole
        let length = Self.fadeLength / whole
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
