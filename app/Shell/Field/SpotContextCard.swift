import OpenspotCore
import SwiftUI

struct SpotContextCard: View, Equatable {
    enum Icon: Equatable {
        case file(FileIcon)
        case symbol(String)
    }

    let chip: ContextChip
    let icon: Icon
    let isOn: Bool

    var body: some View {
        let shape = SpotRoundShape(radius: SpotTokens.contextCardRadius)
        ZStack {
            shape.fill(SpotTheme.highlight.opacity(SpotTheme.chip))
            picture
                .opacity(chip.isLoading ? SpotTheme.contextLoadingIcon : 1)
        }
        .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
        .modifier(SpotSelectionRing(isSelected: isOn, shape: shape))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var picture: some View {
        switch icon {
        case .file(let file):
            SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.contextIcon)
        case .symbol(let symbol):
            SpotItemIcon(icon: nil, glyph: nil, symbol: symbol, size: SpotTokens.contextIcon)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let kind = chip.value?.kind {
            Group {
                if kind == .text {
                    Text("T")
                } else {
                    Image(systemName: kind == .url ? "link" : "doc.fill")
                }
            }
            .font(SpotType.mark)
            .foregroundStyle(SpotTheme.onSolid)
            .frame(width: SpotTokens.contextBadge, height: SpotTokens.contextBadge)
            .background(SpotTheme.solid, in: SpotRoundShape(radius: SpotTokens.contextBadgeRadius))
            .offset(x: SpotTokens.contextBadgeReach, y: SpotTokens.contextBadgeReach)
        }
    }
}
