import SwiftUI

struct SpotSecondaryText: ViewModifier {
    @Environment(\.spotIsOnSolid) private var isOnSolid

    func body(content: Content) -> some View {
        content.foregroundStyle(isOnSolid ? AnyShapeStyle(SpotTheme.onSolid.opacity(SpotTheme.secondaryLight)) : AnyShapeStyle(SpotTheme.glassSecondary))
    }
}
