import SwiftUI

struct SpotSecondaryText: ViewModifier {
    @Environment(\.spotIsOnSolid) private var isOnSolid
    var strength = SpotTheme.secondaryLight

    func body(content: Content) -> some View {
        content.foregroundStyle((isOnSolid ? SpotTheme.onSolid : SpotTheme.ink).opacity(isOnSolid ? SpotTheme.secondaryLight : strength))
    }
}
