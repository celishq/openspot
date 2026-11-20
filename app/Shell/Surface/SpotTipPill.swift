import OpenspotCore
import SwiftUI

struct SpotTipPill: View {
    let text: String
    var wraps = false

    var body: some View {
        if wraps { note } else { pill }
    }

    private var note: some View {
        let shape = SpotRoundShape(radius: SpotTokens.hintPillHeight / 2)
        return Text(text)
            .font(SpotType.detail)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(SpotTokens.tipLines)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SpotTokens.hintKeyPadding)
            .padding(.vertical, SpotTokens.hintPillInset)
            .frame(maxWidth: SpotTokens.tipWidth, alignment: .leading)
            .fixedSize()
            .background(SpotTheme.cornerFill, in: shape)
            .overlay(shape.strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
    }

    private var pill: some View {
        Text(text)
            .font(SpotType.detail)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, SpotTokens.hintKeyPadding)
            .frame(height: SpotTokens.hintPillHeight)
            .background(SpotTheme.cornerFill, in: Capsule())
            .overlay(Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
    }
}
