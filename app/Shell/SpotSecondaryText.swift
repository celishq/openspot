import SwiftUI

/// Secondary text in the Control Center style: it adds light to what lies behind it, so it takes the colour of the
/// backdrop and reads grey on dark and white on light.
struct SpotSecondaryText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
            .blendMode(.plusLighter)
    }
}
