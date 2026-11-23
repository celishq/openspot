import OpenspotCore
import SwiftUI

struct SpotContextCard: View, Equatable {
    let chip: ContextChip
    let showsBadge: Bool

    var body: some View {
        let shape = SpotRoundShape(radius: SpotTokens.contextCardRadius)
        ZStack {
            picture
                .id(chip.look)
                .transition(.opacity)
                .opacity(chip.isLoading ? SpotTheme.contextLoadingIcon : 1)
        }
        .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
        .background {
            shape.fill(SpotTheme.contextFace)
                .shadow(color: SpotTheme.contextFarShadow, radius: SpotTokens.contextFarShadowRadius, y: SpotTokens.contextFarShadowDrop)
                .shadow(color: SpotTheme.contextNearShadow, radius: SpotTokens.contextNearShadowRadius, y: SpotTokens.contextNearShadowDrop)
        }
        .overlay(SpotRoundShape(radius: SpotTokens.contextCardRadius + SpotTokens.contextBorder).strokeBorder(SpotTheme.contextRim, lineWidth: SpotTokens.contextBorder).padding(-SpotTokens.contextBorder))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var picture: some View {
        switch chip.look {
        case .file(.file(let path)):
            SpotNativeIcon(path: path, size: SpotTokens.contextIcon / IconBody.share)
                .frame(width: SpotTokens.contextCard, height: SpotTokens.contextCard)
                .clipShape(SpotRoundShape(radius: SpotTokens.contextCardRadius))
        case .file(let file):
            SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.contextIcon / IconBody.share)
                .frame(width: SpotTokens.contextIcon, height: SpotTokens.contextIcon)
                .clipShape(SpotRoundShape(radius: SpotTokens.contextIconRadius))
        case .symbol(let symbol):
            Image(systemName: symbol)
                .font(SpotType.contextTile)
                .foregroundStyle(SpotTheme.contextTileInk)
                .frame(width: SpotTokens.contextIcon, height: SpotTokens.contextIcon)
                .background(SpotRoundShape(radius: SpotTokens.contextIconRadius).fill(LinearGradient(colors: [SpotTheme.contextTileTop, SpotTheme.contextTileBottom], startPoint: .top, endPoint: .bottom)))
        }
    }

    @ViewBuilder
    private var badge: some View {
        if showsBadge, let kind = chip.value?.kind {
            let leaf = SpotLeafShape(radius: SpotTokens.contextIconRadius)
            glyph(of: kind)
                .font(SpotType.contextBadge)
                .modifier(SpotSecondaryText())
                .offset(x: SpotTokens.contextBadgeNudge, y: SpotTokens.contextBadgeNudge)
                .frame(width: SpotTokens.contextBadge, height: SpotTokens.contextBadge)
                .background(leaf.fill(SpotTheme.contextFace))
                .overlay(alignment: .topLeading) { SpotLeafSeam(radius: SpotTokens.contextIconRadius).stroke(SpotTheme.contextRim, lineWidth: SpotTokens.contextBorder) }
                .padding(SpotTokens.contextInset)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func glyph(of kind: ContextValue.Kind) -> some View {
        switch kind {
        case .url: Image(systemName: "globe")
        case .text: Text(verbatim: "T")
        case .file: Image(systemName: "doc.fill")
        }
    }
}
