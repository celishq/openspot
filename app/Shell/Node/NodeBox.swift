import OpenspotCore
import SwiftUI

struct NodeBox: View {
    let children: [String]
    let style: Style
    let tree: ViewTree
    var outset: CGFloat = 0

    var body: some View {
        NodeArrangement(style: style, outset: outset) {
            ForEach(children, id: \.self) { id in
                if let node = tree.node(id) {
                    NodeView(node: node, tree: tree)
                }
            }
        }
    }
}
