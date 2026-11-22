import OpenspotCore
import SwiftUI

struct NodeFace: View {
    let node: ViewNode
    let tree: ViewTree
    let isSelected: Bool
    @Environment(\.spotNode) private var context
    @State private var isHovered = false
    @GestureState private var isPressed = false

    var body: some View {
        let variants = context.variants
        let given = tree.states(in: variants, pressed: isPressed, hovered: isHovered, selected: isSelected)
        let style = node.style.resolved(for: given)
        if style.isHidden != true {
            content(style)
                .environment(\.spotNode.variants, node.kind == BlockKind.button.word ? given : variants)
                .modifier(NodeLook(style: style, drawsFill: !takesLook))
                .modifier(NodeHover(isFollowed: tree.tracksHover(node), isHovered: $isHovered))
                .modifier(NodePress(isFollowed: !isOnCard && tree.follows([.pressed], at: node), isPressed: $isPressed))
                .layoutValue(key: NodeSlot.self, value: style)
        }
    }

    private var isOnCard: Bool {
        context.variants.contains(.card)
    }

    private var takesLook: Bool {
        BlockKind.controlWords.contains(node.kind) && (node.kind != BlockKind.button.word || node.children.isEmpty)
    }

    @ViewBuilder
    private func content(_ style: Style) -> some View {
        switch node.kind {
        case BlockKind.box: NodeBox(children: node.children, style: style, tree: tree)
        case BlockKind.text.word: NodeText(title: node.title ?? node.value, detail: node.detail, tone: node.tone, icon: node.icon)
        case BlockKind.icon.word: NodeIcon(icon: node.icon, side: node.naturalSize.width)
        case BlockKind.picture.word: NodePicture(icon: node.icon, size: node.naturalSize)
        case BlockKind.button.word where !node.children.isEmpty: control(label: AnyView(NodeBox(children: node.children, style: style, tree: tree)), look: nil)
        case BlockKind.field.word where node.isSearch: NodeSearch()
        case let kind where BlockKind.controlWords.contains(kind): control(label: nil, look: SpotPart.Look(style: style))
        case BlockKind.items: NodeItems(size: node.naturalSize)
        default:
            if let source = node.source { NodeSpotView(id: node.id, values: node.values, source: source) }
        }
    }

    @ViewBuilder
    private func control(label: AnyView?, look: SpotPart.Look?) -> some View {
        if isOnCard {
            NodeCardPart(node: node, label: label, look: look)
        } else {
            SheetPartView(node: node, label: label, look: look)
        }
    }
}
