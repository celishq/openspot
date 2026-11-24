import OpenspotCore
import SwiftUI

struct SpotShake: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    let count: () -> Int

    func body(content: Content) -> some View {
        if reducesMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(0), trigger: count()) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                SpotMotion.shake
            }
        }
    }
}
