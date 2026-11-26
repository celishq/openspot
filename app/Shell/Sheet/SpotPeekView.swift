import OpenspotCore
import SwiftUI

struct SpotPeekView: View {
    let model: SpotsModel
    let row: CGRect?

    var body: some View {
        if let rect = model.peekRect, let source = row ?? model.peekSource {
            let isOpen = model.isPeekOpen
            let shape = SpotSurfaceShape(rect: isOpen ? rect : source, radius: SpotTokens.cardRadius)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .spotGlass(in: shape)
                    .morph(isOpen ? 1 : 0, opacity: { 1 - SheetMorph.cardOpacity(at: $0) })
                if let peek = model.peek {
                    PeekFace(model: model, peek: peek)
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

private struct PeekVideo: View {
    let model: SpotsModel
    let path: String

    var body: some View {
        SpotPeekVideo(path: path, isPlaying: model.peekPlays)
    }
}

private struct PeekFace: View {
    let model: SpotsModel
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
        case .picture(let path):
            SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: nil))
                .clipShape(inner)
        case .file(let path):
            SpotPeekThumbnail(path: path)
        case .video(let path):
            PeekVideo(model: model, path: path)
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
        case .blocks(let tree):
            NodeTree(tree: tree, pictureTimes: [:])
                .environment(\.spotNode, NodeContext(variants: Peek.variants))
                .padding(SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
    }
}
