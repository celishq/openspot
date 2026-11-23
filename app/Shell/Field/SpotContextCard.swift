import OpenspotCore
import SwiftUI

struct SpotContextCard: View, Equatable {
    let chip: ContextChip
    let isOn: Bool
    let showsBadge: Bool

    var body: some View {
        let shape = SpotRoundShape(radius: SpotTokens.contextCardRadius)
        ZStack {
            shape.fill(SpotTheme.highlight.opacity(SpotTheme.chip))
            picture
                .id(chip.look)
                .transition(.opacity)
                .opacity(chip.isLoading ? SpotTheme.contextLoadingIcon : 1)
        }
        .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
        .overlay(shape.strokeBorder(SpotTheme.ink.opacity(SpotTheme.track), lineWidth: SpotTokens.contextBorder))
        .modifier(SpotSelectionRing(isSelected: isOn, shape: shape))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var picture: some View {
        switch chip.look {
        case .file(let file):
            SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.contextIcon)
        case .symbol(let symbol):
            SpotItemIcon(icon: nil, glyph: nil, symbol: symbol, size: SpotTokens.contextIcon)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if showsBadge, let kind = chip.value?.kind {
            Image(systemName: ContextPreview.symbol(of: kind))
                .font(SpotType.mark)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .frame(width: SpotTokens.contextBadge, height: SpotTokens.contextBadge)
                .background(SpotTheme.cornerFill, in: Circle())
                .overlay(Circle().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track), lineWidth: SpotTokens.contextBorder))
                .offset(x: SpotTokens.contextBadgeReach, y: SpotTokens.contextBadgeReach)
                .transition(.opacity)
        }
    }
}
