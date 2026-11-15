import OpenspotCore
import SwiftUI

struct SpotHint: View {
    let words: HintWords
    var activeKey: String?
    var onPress: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: SpotTokens.hintGroupGap) {
            ForEach(Array(words.groups.enumerated()), id: \.offset) { _, group in
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
        .padding(.leading, words.groups.first?.key == nil ? SpotTokens.hintEndPadding : SpotTokens.hintKeyInset)
        .padding(.trailing, SpotTokens.hintEndPadding)
        .frame(height: SpotTokens.hintPillHeight)
        .modifier(SpotGlass(radius: SpotTokens.hintHeight / 2 + SpotTokens.hintPillInset, isBare: words.groups.isEmpty))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func words(of group: HintWords.Group) -> some View {
        HStack(spacing: SpotTokens.hintKeyGap) {
            if let key = group.key {
                Text(key)
                    .padding(.horizontal, SpotTokens.hintKeyPadding)
                    .frame(height: SpotTokens.hintKeyHeight)
                    .background(SpotTheme.ink.opacity(SpotTheme.track), in: Capsule())
                    .modifier(SpotSelectionRing(isSelected: key == activeKey, shape: Capsule(), width: SpotSelectionRing<Capsule>.thinWidth))
            }
            if !group.words.isEmpty {
                Text(group.words)
            }
        }
    }
}
