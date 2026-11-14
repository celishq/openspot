import OpenspotCore
import SwiftUI

struct SpotTipPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SpotType.detail)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, SpotTokens.hintKeyPadding)
            .frame(height: SpotTokens.hintPillHeight)
            .background(SpotTheme.keycap, in: Capsule())
            .overlay(Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
    }
}
