import OpenspotCore
import SwiftUI

struct SpotAttachmentCard: View, Equatable {
    let chip: AttachmentChip
    let showsBadge: Bool
    let isQuiet: Bool

    var body: some View {
        let shape = SpotRoundShape(radius: SpotTokens.attachmentCardRadius)
        ZStack {
            if !chip.isLoading {
                picture
                    .id(chip.look)
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.attachmentCard, height: SpotTokens.attachmentCard)
        .background {
            shape.fill(SpotTheme.attachmentFace)
                .shadow(color: SpotTheme.attachmentFarShadow, radius: SpotTokens.attachmentFarShadowRadius, y: SpotTokens.attachmentFarShadowDrop)
                .shadow(color: SpotTheme.attachmentNearShadow, radius: SpotTokens.attachmentNearShadowRadius, y: SpotTokens.attachmentNearShadowDrop)
                .opacity(isQuiet ? MotionTokens.hiddenOpacity : 1)
        }
        .overlay(SpotRoundShape(radius: SpotTokens.attachmentCardRadius + SpotTokens.attachmentBorder).strokeBorder(SpotTheme.attachmentRim, lineWidth: SpotTokens.attachmentBorder).padding(-SpotTokens.attachmentBorder).opacity(isQuiet ? MotionTokens.hiddenOpacity : 1))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var picture: some View {
        switch chip.look {
        case .file(.file(let path)):
            SpotNativeIcon(path: path, size: SpotTokens.attachmentIcon / IconBody.share)
                .frame(width: SpotTokens.attachmentCard, height: SpotTokens.attachmentCard)
                .clipShape(SpotRoundShape(radius: SpotTokens.attachmentCardRadius))
                .grayscale(isQuiet ? 1 : 0)
                .opacity(isQuiet ? SpotTheme.attachmentQuietPicture : 1)
        case .file(let file):
            SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.attachmentIcon / IconBody.share)
                .frame(width: SpotTokens.attachmentIcon, height: SpotTokens.attachmentIcon)
                .clipShape(SpotRoundShape(radius: SpotTokens.attachmentIconRadius))
                .grayscale(isQuiet ? 1 : 0)
                .opacity(isQuiet ? SpotTheme.attachmentQuietPicture : 1)
        case .symbol(let symbol):
            let tile = SpotRoundShape(radius: SpotTokens.attachmentIconRadius)
            ZStack {
                tile.fill(LinearGradient(colors: [SpotTheme.attachmentTileTop, SpotTheme.attachmentTileBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Image(systemName: symbol).font(SpotType.attachmentTile).foregroundStyle(SpotTheme.attachmentTileInk))
                    .opacity(isQuiet ? MotionTokens.hiddenOpacity : 1)
                tile.fill(SpotTheme.attachmentQuietFill)
                    .overlay(Image(systemName: symbol).font(SpotType.attachmentTile).modifier(SpotSecondaryText()))
                    .opacity(isQuiet ? 1 : MotionTokens.hiddenOpacity)
            }
            .frame(width: SpotTokens.attachmentIcon, height: SpotTokens.attachmentIcon)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if showsBadge, let kind = chip.value?.kind {
            let leaf = SpotLeafShape(radius: SpotTokens.attachmentIconRadius)
            glyph(of: kind.badge)
                .font(SpotType.attachmentBadge)
                .modifier(SpotSecondaryText())
                .offset(x: SpotTokens.attachmentBadgeNudge, y: SpotTokens.attachmentBadgeNudge)
                .frame(width: SpotTokens.attachmentBadge, height: SpotTokens.attachmentBadge)
                .background(leaf.fill(SpotTheme.attachmentFace))
                .overlay(alignment: .topLeading) { SpotLeafShape(radius: SpotTokens.attachmentIconRadius, isSeam: true).stroke(SpotTheme.attachmentRim, lineWidth: SpotTokens.attachmentBorder) }
                .padding(SpotTokens.attachmentInset)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func glyph(of badge: AttachmentValue.Kind.Badge) -> some View {
        switch badge {
        case .symbol(let symbol): Image(systemName: symbol)
        case .letter(let letter): Text(verbatim: letter)
        }
    }
}
