import OpenspotCore
import SwiftUI

struct SpotPreviewView: View {
    let model: SpotsModel

    var body: some View {
        let shape = SpotRoundShape(SurfaceEdge.sheet)
        ZStack(alignment: .topLeading) {
            if let preview = model.preview {
                NodeTree(tree: preview.tree, pictureTimes: [:])
                    .environment(\.spotNode, NodeContext(variants: ItemPreview.variants))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(preview.run)
            }
        }
        .padding(SpotTokens.padding * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(shape)
        .spotGlass(in: shape)
        .environment(\.spotIsShown, true)
    }
}
