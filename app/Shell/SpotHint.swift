import OpenspotCore
import SwiftUI

/// The keys that work now, on the surface of a toast, under the content of the panel. Each key lies on a chip beside its words.
struct SpotHint: View {
    let text: String

    var body: some View {
        HStack(spacing: SpotTokens.hintGroupGap) {
            ForEach(Array(HintWords(text).groups.enumerated()), id: \.offset) { _, group in
                HStack(spacing: SpotTokens.hintKeyGap) {
                    if let key = group.key {
                        Text(key)
                            .padding(.horizontal, SpotTokens.hintKeyPadding)
                            .frame(height: SpotTokens.hintKeyHeight)
                            .background(SpotTheme.ink.opacity(SpotTheme.track), in: Capsule())
                    }
                    if !group.words.isEmpty {
                        Text(group.words)
                    }
                }
            }
        }
        .font(SpotType.detail)
        .foregroundStyle(SpotTheme.ink)
        .lineLimit(1)
        .padding(.leading, HintWords(text).groups.first?.key == nil ? SpotTokens.hintEndPadding : SpotTokens.hintKeyInset)
        .padding(.trailing, SpotTokens.hintEndPadding)
        .frame(height: SpotTokens.hintPillHeight)
        .modifier(SpotGlass(radius: SpotTokens.hintHeight / 2 + SpotTokens.hintPillInset, isBare: text.isEmpty))
        .frame(maxWidth: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }
}
