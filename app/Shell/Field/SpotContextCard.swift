import OpenspotCore
import SwiftUI

struct SpotContextCard: View, Equatable {
    let chip: ContextChip
    let showsBadge: Bool

    var body: some View {
        ZStack {
            picture
                .id(chip.look)
                .transition(.opacity)
                .opacity(chip.isLoading ? SpotTheme.contextLoadingIcon : 1)
        }
        .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var picture: some View {
        switch chip.look {
        case .file(let file):
            SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.contextCard / IconBody.share)
                .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
        case .symbol(let symbol):
            let shape = SpotRoundShape(radius: SpotTokens.contextCardRadius)
            SpotItemIcon(icon: nil, glyph: nil, symbol: symbol, size: SpotTokens.contextSymbol)
                .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
                .background {
                    shape.fill(SpotTheme.contextFace)
                        .shadow(color: SpotTheme.contextNearShadow, radius: SpotTokens.contextNearShadowRadius, y: SpotTokens.contextNearShadowDrop)
                }
                .overlay(shape.strokeBorder(SpotTheme.contextRim, lineWidth: SpotTokens.contextBorder))
        }
    }

    @ViewBuilder
    private var badge: some View {
        if showsBadge, let kind = chip.value?.kind {
            Image(systemName: ContextPreview.symbol(of: kind))
                .font(SpotType.contextBadge)
                .foregroundStyle(SpotTheme.contextBadgeInk)
                .frame(width: SpotTokens.contextBadge, height: SpotTokens.contextBadge)
                .background {
                    Circle()
                        .fill(SpotTheme.contextBadgeFace)
                        .shadow(color: SpotTheme.contextBadgeShadow, radius: SpotTokens.contextBadgeShadowRadius, y: SpotTokens.contextBadgeShadowDrop)
                }
                .overlay(Circle().strokeBorder(SpotTheme.contextBadgeRim, lineWidth: SpotTokens.contextBadgeBorder))
                .offset(x: SpotTokens.contextBadgeReach, y: SpotTokens.contextBadgeReach)
                .transition(.opacity)
        }
    }
}
