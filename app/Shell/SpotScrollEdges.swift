import SwiftUI

/// How strongly each end of the scroll area fades, from 0 to 1.
struct SpotScrollEdges: Equatable {
    var top = 0.0
    var bottom = 0.0

    private static let fadeLength = 56.0

    var gradient: LinearGradient {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private var stops: [Gradient.Stop] {
        let start = (SpotTokens.halo + SpotTokens.rowHeight) / SpotTokens.panelHeight
        let end = 1 - SpotTokens.halo / SpotTokens.panelHeight
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
        if #available(macOS 15.0, *) {
            content.onScrollGeometryChange(for: SpotScrollEdges.self, of: { geometry in
                let below = geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
                return SpotScrollEdges(
                    top: min(max(geometry.contentOffset.y / Self.fadeDistance, 0), 1),
                    bottom: min(max(below / Self.fadeDistance, 0), 1)
                )
            }, action: { _, new in
                edges = new
            })
        } else {
            content
        }
    }
}
