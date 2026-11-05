import SwiftUI

/// Secondary text in the Control Center style: it adds light to what lies behind it, so it takes the colour of the
/// backdrop and reads grey on dark and white on light. On a white card it is plain dark text.
struct SpotSecondaryText: ViewModifier {
    var isOnWhite = false

    func body(content: Content) -> some View {
        if isOnWhite {
            content.foregroundStyle(.black.opacity(SpotTokens.secondaryLight))
        } else {
            content
                .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
                .blendMode(.plusLighter)
        }
    }
}
