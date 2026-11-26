import OpenspotCore
import SwiftUI

struct SpotPeekView: View {
    let model: SpotsModel

    var body: some View {
        if let rect = model.peekRect, let source = model.peekSource {
            let isOpen = model.isPeekOpen
            let shape = SpotSurfaceShape(rect: isOpen ? rect : source, radius: SpotTokens.cardRadius)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .spotGlass(in: shape)
                if let peek = model.peek {
                    PeekFace(peek: peek)
                        .id(peek.run)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .morph(isOpen ? 1 : 0, opacity: { SheetMorph.contentOpacity(at: $0, isOpen: isOpen) })
                        .clipShape(shape)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct PeekFace: View {
    let peek: Peek

    private var inner: SpotRoundShape {
        SpotRoundShape(SurfaceEdge.sheet.inner())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.padding) {
            look
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(peek.title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                if let caption = peek.caption {
                    Text(caption)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, SpotTokens.padding)
        }
        .padding(SpotTokens.padding)
    }

    @ViewBuilder
    private var look: some View {
        switch peek.look {
        case .picture(let path), .file(let path):
            Color.clear
                .overlay { NodeFileThumbnail(path: path) }
                .clipShape(inner)
        case .color(let hex):
            inner.fill(SpotColorBar.color(hex))
        case .text(let text):
            Text(text)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .padding(SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        case .link(let url, let host):
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Image(systemName: "link")
                    .font(SpotType.itemSymbol(side: SpotTokens.listIconSize))
                    .foregroundStyle(SpotTheme.glassInk)
                    .frame(width: SpotTokens.listIconSize, height: SpotTokens.listIconSize, alignment: .leading)
                if let host {
                    Text(host)
                        .font(SpotType.title)
                        .foregroundStyle(SpotTheme.ink)
                        .lineLimit(1)
                }
                Text(url)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(4)
            }
            .padding(SpotTokens.padding)
        }
    }
}
