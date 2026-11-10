import OpenspotCore
import SwiftUI

/// Moves the lifted card, or its glass, as far as the pointer moved it. Only the lifted card reads the lift, so a move of
/// the pointer redraws this modifier alone.
struct SpotLiftOffset: ViewModifier {
    let lift: SpotLift?

    func body(content: Content) -> some View {
        content.offset(lift?.offset ?? .zero)
    }
}
