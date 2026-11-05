import SwiftUI

/// The keys that work now, as a quiet line under the content of the panel.
struct SpotHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SpotType.detail)
            .modifier(SpotSecondaryText(strength: SpotTokens.hintLight))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: SpotTokens.hintHeight, maxHeight: SpotTokens.hintHeight, alignment: .center)
            .allowsHitTesting(false)
    }
}
