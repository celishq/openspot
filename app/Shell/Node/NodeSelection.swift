import OpenspotCore
import SwiftUI

struct NodeSelection: View {
    let node: ViewNode
    let tree: ViewTree
    @Environment(\.spotNode) private var context

    var body: some View {
        NodeFace(node: node, tree: tree, isSelected: context.host.isSelected(node, in: tree))
    }
}
