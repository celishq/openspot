import SwiftUI

struct SpotRoundShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        SpotSurfaceShape(rect: rect, radius: radius).path(in: rect)
    }
}
