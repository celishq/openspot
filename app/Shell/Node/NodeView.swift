import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotNodeVariants: Set<Style.Variant> = [.sheet]
    @Entry var spotPictureTimes: [String: Double] = [:]
    @Entry var spotNodeSend: ((String, String) -> Void)?
    @Entry var spotNodeSelection: (() -> String?)?
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
