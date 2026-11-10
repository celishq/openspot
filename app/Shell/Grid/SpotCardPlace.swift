import OpenspotCore
import SwiftUI

/// Where a card lies, in one offset: its place in the grid with the push of an open sheet, or, while the person lifts it,
/// the place it started at moved as far as the pointer moved it. Only the lifted card reads the lift, so a move of the
/// pointer redraws this modifier alone.
struct SpotCardPlace: ViewModifier {
    let motion: SpotPushedCard
    let lift: SpotLift?

    func body(content: Content) -> some View {
        var motion = motion
        if let lift {
            motion.offset = CGSize(width: motion.base.width + lift.offset.width, height: motion.base.height + lift.offset.height)
        }
        return content.modifier(motion)
    }
}
