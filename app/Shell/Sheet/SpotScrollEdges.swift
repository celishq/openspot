import OpenspotCore
import SwiftUI

struct SpotScrollEdges: Equatable {
    var top = 0.0
    var bottom = 0.0

    static func end(fading strength: Double, from edge: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: SpotTheme.mask.opacity(1 - strength), location: 0),
            .init(color: SpotTheme.mask.opacity(1 - SpotTheme.fadeNear * strength), location: 1.0 / SpotTheme.fadeSteps),
            .init(color: SpotTheme.mask.opacity(1 - SpotTheme.fadeFar * strength), location: 2 / SpotTheme.fadeSteps),
            .init(color: SpotTheme.mask, location: 1)
        ], startPoint: edge, endPoint: edge == .top ? .bottom : .top)
    }

    func gradient(height: CGFloat) -> LinearGradient {
        LinearGradient(stops: levels(height: height).map { .init(color: SpotTheme.mask.opacity($0.strength), location: $0.location) }, startPoint: .top, endPoint: .bottom)
    }

    private func levels(height: CGFloat) -> [(location: CGFloat, strength: Double)] {
        let start = (SpotTokens.halo + SpotTokens.rowHeight) / SpotTokens.panelHeight
        let end = (height - SpotTokens.halo - SpotTokens.hintBlock) / SpotTokens.panelHeight
        let length = SpotTokens.scrollFadeLength / SpotTokens.panelHeight
        return [
            (start, 1 - top),
            (start + length / SpotTheme.fadeSteps, 1 - SpotTheme.fadeNear * top),
            (start + 2 * length / SpotTheme.fadeSteps, 1 - SpotTheme.fadeFar * top),
            (start + length, 1),
            (end - length, 1),
            (end - 2 * length / SpotTheme.fadeSteps, 1 - SpotTheme.fadeFar * bottom),
            (end - length / SpotTheme.fadeSteps, 1 - SpotTheme.fadeNear * bottom),
            (end, 1 - bottom)
        ]
    }
}

struct SpotScrollEdgeTracker: ViewModifier {
    @Binding var edges: SpotScrollEdges

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: SpotScrollEdges.self, of: { geometry in
            let below = geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
            return SpotScrollEdges(
                top: min(max(geometry.contentOffset.y / SpotTokens.scrollFadeDistance, 0), 1),
                bottom: min(max(below / SpotTokens.scrollFadeDistance, 0), 1)
            )
        }, action: { _, new in
            edges = new
        })
    }
}
