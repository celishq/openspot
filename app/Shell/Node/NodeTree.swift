import OpenspotCore
import SwiftUI

struct NodeTree: View {
    let tree: ViewTree
    let pictureTimes: [String: Double]
    var outset: CGFloat = 0
    @Environment(\.spotNode) private var context
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let variants = context.variants.union([scheme == .dark ? .dark : .light])
        let style = tree.style.resolved(for: variants)
        NodeBox(children: tree.children, style: style, tree: tree, outset: outset)
            .environment(\.spotNode.variants, variants)
            .modifier(NodeLook(style: style))
            .font(SpotType.body)
            .modifier(SpotInk())
            .environment(\.spotPictureTimes, pictureTimes)
    }
}
