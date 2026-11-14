import SwiftUI

struct SpotOutsideShape: Shape {
    var inner: SpotSurfaceShape

    var animatableData: SpotSurfaceShape.AnimatableData {
        get { inner.animatableData }
        set { inner.animatableData = newValue }
    }

    func path(in bounds: CGRect) -> Path {
        var path = Path(bounds)
        path.addPath(inner.path(in: bounds))
        return path
    }
}
