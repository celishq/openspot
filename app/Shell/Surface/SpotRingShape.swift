import SwiftUI

struct SpotRingShape<Edge: InsettableShape>: Shape {
    var edge: Edge
    let width: CGFloat

    var animatableData: Edge.AnimatableData {
        get { edge.animatableData }
        set { edge.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = edge.path(in: rect)
        path.addPath(edge.inset(by: width).path(in: rect))
        return path
    }
}

extension SpotColor {
    func ring(of edge: some InsettableShape, width: CGFloat) -> some View {
        clipShape(SpotRingShape(edge: edge, width: width), style: FillStyle(eoFill: true))
    }
}
