import OpenspotCore
import SwiftUI

/// The keys that work now, on the surface of a toast, under the content of the panel. Each key lies on a chip beside its words,
/// and a click on a key and its words does what the key does.
struct SpotHint: View {
    let text: String
    var onPress: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: SpotTokens.hintGroupGap) {
            ForEach(Array(HintWords(text).groups.enumerated()), id: \.offset) { _, group in
                if let key = group.key {
                    Button { onPress(key) } label: { words(of: group).contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                } else {
                    words(of: group)
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
    }

    private func words(of group: HintWords.Group) -> some View {
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
