import OpenspotCore
import SwiftUI

struct NodeFace: View {
    let node: ViewNode
    let tree: ViewTree
    let isSelected: Bool
    @Environment(\.spotNodeVariants) private var variants
    @State private var isHovered = false
    @GestureState private var isPressed = false

    var body: some View {
        let given = variants.union(isPressed ? [.pressed] : []).union(isSelected ? [.selected, .focus] : [])
        let style = node.style.resolved(for: isHovered ? given.union([.hover]) : given)
        if style.isHidden != true {
            content(style)
                .environment(\.spotNodeVariants, node.kind == BlockKind.button.word ? given : variants)
                .modifier(NodeLook(style: style))
                .modifier(NodeHover(isFollowed: node.style.named.contains(.hover), isHovered: $isHovered))
                .modifier(NodePress(isFollowed: !variants.contains(.card) && tree.follows([.pressed], at: node), isPressed: $isPressed))
                .layoutValue(key: NodeSlot.self, value: style)
        }
    }

    @ViewBuilder
    private func content(_ style: Style) -> some View {
        switch node.kind {
        case BlockKind.box: NodeBox(children: node.children, style: style, tree: tree)
        case BlockKind.text.word: NodeText(title: node.title ?? node.value, detail: node.detail, tone: node.tone, symbol: node.icon?.symbol)
        case BlockKind.icon.word: NodeIcon(icon: node.icon)
        case BlockKind.picture.word: NodePicture(icon: node.icon)
        case BlockKind.button.word where !node.children.isEmpty: NodePart(id: node.id, label: AnyView(NodeBox(children: node.children, style: style, tree: tree)))
        case BlockKind.button.word, BlockKind.field.word, BlockKind.toggle.word, BlockKind.choice.word, BlockKind.number.word: NodePart(id: node.id, label: nil)
        case BlockKind.items: NodeItems()
        default:
            if let source = node.source { NodeSpotView(id: node.id, values: node.values, source: source) }
        }
    }
}
