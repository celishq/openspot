import SwiftUI

struct SpotEdgeFade: Equatable, Sendable {
    let edges: SpotScrollEdges
    let height: CGFloat

    func strength(of frame: CGRect) -> Double {
        edges.strength(at: frame.midY, height: height)
    }
}
