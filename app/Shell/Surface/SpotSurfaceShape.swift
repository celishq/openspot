import OpenspotCore
import SwiftUI

struct SpotSurfaceShape: InsettableShape {
    var rect: CGRect
    var radius: CGFloat
    var inset: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(AnimatablePair(rect.width, rect.height), radius)) }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first.first, height: newValue.second.first.second)
            radius = newValue.second.second
        }
    }

    func path(in bounds: CGRect) -> Path {
        SpotRoundShape(SurfaceEdge(radius: radius, inset: inset)).path(in: rect)
    }

    func inset(by amount: CGFloat) -> SpotSurfaceShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}
