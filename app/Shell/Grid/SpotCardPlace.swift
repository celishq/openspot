import OpenspotCore
import SwiftUI

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
