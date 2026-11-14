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
        let place = rect.insetBy(dx: inset, dy: inset)
        let corner = min(max(radius - inset, 0), min(place.width, place.height) / 2)
        return RoundedRectangle(cornerRadius: corner, style: Self.style(corner: corner, in: place)).path(in: place)
    }

    static func style(corner: CGFloat, in rect: CGRect) -> RoundedCornerStyle {
        2 * corner >= min(rect.width, rect.height) ? .circular : .continuous
    }

    func inset(by amount: CGFloat) -> SpotSurfaceShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}
