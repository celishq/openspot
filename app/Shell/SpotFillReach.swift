import SwiftUI

/// Cuts a view to a circle around a point, which covers the whole frame or nothing. A change between the two grows the circle
/// out of the point or shrinks it into the point, so that each place shows one look or the other and never half of each.
struct SpotFillReach: ViewModifier {
    let size: CGSize
    let center: CGPoint
    let covers: Bool

    func body(content: Content) -> some View {
        let reach = covers ? 2 * hypot(size.width, size.height) : 0
        content.mask(alignment: .topLeading) {
            Circle()
                .frame(width: reach, height: reach)
                .offset(x: center.x - reach / 2, y: center.y - reach / 2)
        }
    }
}
