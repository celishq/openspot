import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotPictureTimes: [String: Double] = [:]
}

struct NodeView: View {
    let node: ViewNode
    let tree: ViewTree

    var body: some View {
        if tree.follows([.selected, .focus], at: node) {
            NodeSelection(node: node, tree: tree)
        } else {
            NodeFace(node: node, tree: tree, isSelected: false)
        }
    }
}
