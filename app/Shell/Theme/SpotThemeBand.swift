import OpenspotCore
import SwiftUI

struct SpotThemeBand: ViewModifier {
    var isChosen = false

    static var shape: SpotRoundShape {
        SpotRoundShape(radius: SpotTokens.themeRowRadius)
    }

    static func fill(isChosen: Bool) -> some View {
        shape.fill(isChosen ? SpotTheme.ink.opacity(SpotTheme.chosenRow) : .clear)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, SpotTokens.themeRowPadding)
            .frame(height: SpotTokens.themeLine)
            .background { Self.fill(isChosen: isChosen) }
            .contentShape(Self.shape)
    }
}
