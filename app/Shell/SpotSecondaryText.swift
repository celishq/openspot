import SwiftUI

/// Secondary text: ink at less strength, so it stays below the title on any backdrop.
struct SpotSecondaryText: ViewModifier {
    var isOnSolid = false
    var strength = SpotTheme.secondaryLight

    func body(content: Content) -> some View {
        content.foregroundStyle((isOnSolid ? SpotTheme.onSolid : SpotTheme.ink).opacity(isOnSolid ? SpotTheme.secondaryLight : strength))
    }
}
