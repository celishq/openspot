import OpenspotCore
import SwiftUI

struct SpotButtonKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(SpotType.detail)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, SpotTokens.hintKeyPadding)
            .frame(height: SpotTokens.hintPillHeight)
            .overlay(Capsule().strokeBorder(.secondary.opacity(SpotTheme.track)))
    }
}
