import SwiftUI

/// All of the view it fills but a surface shape, as a mask that hides a layer where the shape lies. It animates with the
/// shape, so that the hole follows a surface that grows.
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
