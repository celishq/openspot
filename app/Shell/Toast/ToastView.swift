import OpenspotCore
import SwiftUI

struct ToastView: View {
    let toast: Toast

    var body: some View {
        content
            .padding(.horizontal, SpotTokens.toastMargin)
            .padding(.vertical, SpotTokens.toastPaddingY)
    }

    @ViewBuilder
    private var content: some View {
        if let tree = toast.note.tree {
            NodeTree(tree: tree, pictureTimes: [:])
                .environment(\.spotSurfaceEdge, SurfaceEdge(radius: SpotTokens.toastRadius).inner(by: SpotTokens.toastPaddingY))
                .environment(\.spotNode, NodeContext(variants: [.toast]))
                .fixedSize()
                .allowsHitTesting(false)
        } else {
            HStack(spacing: SpotTokens.toastGlyphGap) {
                if toast.note.kind == .work {
                    SpotWorkMark(call: nil, side: SpotTokens.toastMarkSide)
                } else if let symbol = toast.note.kind.symbol {
                    Image(systemName: symbol)
                        .font(SpotType.strong)
                        .foregroundStyle(SpotTheme.ink)
                }
                KeyFill.text(toast.words)
                    .textRenderer(KeyFill(fill: SpotTheme.highlight.opacity(SpotTheme.track).color))
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
