import OpenspotCore
import SwiftUI

struct SpotScrollEdges: Equatable {
    var top = 0.0
    var bottom = 0.0

    static let fadeLength = 56.0

    static func end(fading strength: Double, from edge: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .black.opacity(1 - strength), location: 0),
            .init(color: .black.opacity(1 - 0.6 * strength), location: 1.0 / 3),
            .init(color: .black.opacity(1 - 0.2 * strength), location: 2.0 / 3),
            .init(color: .black, location: 1)
        ], startPoint: edge, endPoint: edge == .top ? .bottom : .top)
    }

    func gradient(height: CGFloat) -> LinearGradient {
        LinearGradient(stops: levels(height: height).map { .init(color: .black.opacity($0.strength), location: $0.location) }, startPoint: .top, endPoint: .bottom)
    }

    func strength(at y: CGFloat, height: CGFloat) -> Double {
        let levels = levels(height: height)
        let place = y / SpotTokens.panelHeight
        guard let after = levels.firstIndex(where: { $0.location >= place }) else { return levels.last?.strength ?? 1 }
        guard after > 0 else { return levels[0].strength }
        let low = levels[after - 1]
        let high = levels[after]
        let share = high.location > low.location ? (place - low.location) / (high.location - low.location) : 1
        return low.strength + (high.strength - low.strength) * share
    }

    private func levels(height: CGFloat) -> [(location: CGFloat, strength: Double)] {
        let start = (SpotTokens.halo + SpotTokens.rowHeight) / SpotTokens.panelHeight
        let end = (height - SpotTokens.halo - SpotTokens.hintBlock) / SpotTokens.panelHeight
        let length = Self.fadeLength / SpotTokens.panelHeight
        return [
            (start, 1 - top),
            (start + length / 3, 1 - 0.6 * top),
            (start + 2 * length / 3, 1 - 0.2 * top),
            (start + length, 1),
            (end - length, 1),
            (end - 2 * length / 3, 1 - 0.2 * bottom),
            (end - length / 3, 1 - 0.6 * bottom),
            (end, 1 - bottom)
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
