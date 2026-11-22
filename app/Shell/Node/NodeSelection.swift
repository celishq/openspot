import OpenspotCore
import SwiftUI

struct NodeSelection: View {
    let node: ViewNode
    let tree: ViewTree
    @Environment(\.spotNodeSelection) private var selection

    var body: some View {
        NodeFace(node: node, tree: tree, isSelected: selection.map { tree.isSelected(node, selection: $0) } ?? false)
    }
}
