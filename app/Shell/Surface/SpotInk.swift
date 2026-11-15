import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsOnSolid = false
}

struct SpotInk: ViewModifier {
    @Environment(\.spotIsOnSolid) private var isOnSolid

    func body(content: Content) -> some View {
        content.foregroundStyle(isOnSolid ? SpotTheme.onSolid : SpotTheme.ink)
    }
}
