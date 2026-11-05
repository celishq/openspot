import SwiftUI

/// The prompt of an empty text field, in the same secondary text as the rest of the panel.
struct SpotFieldPrompt: ViewModifier {
    let text: String
    let isShown: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if isShown {
                Text(text)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
        }
    }
}
