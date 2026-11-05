import SwiftUI

/// Secondary text: plain white at less strength, so it stays below the title on any backdrop. On a white card it is
/// plain dark text.
struct SpotSecondaryText: ViewModifier {
    var isOnWhite = false
    var strength = SpotTokens.secondaryLight

    func body(content: Content) -> some View {
        content.foregroundStyle(isOnWhite ? .black.opacity(SpotTokens.secondaryLight) : .white.opacity(strength))
    }
}
