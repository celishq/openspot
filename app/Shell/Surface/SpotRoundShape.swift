import OpenspotCore
import SwiftUI

struct SpotRoundShape: InsettableShape {
    var edge: SurfaceEdge

    init(_ edge: SurfaceEdge) {
        self.edge = edge
    }

    init(radius: CGFloat) {
        edge = SurfaceEdge(radius: radius)
    }

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: edge.corner(in: rect), style: edge.isCircular(in: rect) ? .circular : .continuous).path(in: edge.place(in: rect))
    }

    func inset(by amount: CGFloat) -> SpotRoundShape {
        SpotRoundShape(edge.inset(by: amount))
    }
}

extension EnvironmentValues {
    @Entry var spotSurfaceEdge = SurfaceEdge.sheet
}
