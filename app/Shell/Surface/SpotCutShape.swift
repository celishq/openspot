import SwiftUI

struct SpotCutShape: Shape {
    var shape: SpotSurfaceShape
    var cut: SpotSurfaceShape

    var animatableData: AnimatablePair<SpotSurfaceShape.AnimatableData, SpotSurfaceShape.AnimatableData> {
        get { AnimatablePair(shape.animatableData, cut.animatableData) }
        set {
            shape.animatableData = newValue.first
            cut.animatableData = newValue.second
        }
    }

    func path(in bounds: CGRect) -> Path {
        cut.rect.isEmpty ? shape.path(in: bounds) : shape.path(in: bounds).subtracting(cut.path(in: bounds))
    }
}
