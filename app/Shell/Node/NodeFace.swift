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
                .environment(\.spotNode.variants, node.kind == .button ? given : variants)
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
        BlockKind.controls.contains(node.kind) && (node.kind != .button || node.children.isEmpty)
    }

    @ViewBuilder
    private func content(_ style: Style) -> some View {
        switch node.kind {
        case .box: NodeBox(children: node.children, style: style, tree: tree)
        case .text, .item: NodeText(title: node.title ?? node.value, detail: node.detailWords, tone: node.tone, icon: node.icon)
        case .icon: NodeIcon(icon: node.icon, side: node.naturalSize.width)
        case .picture: NodePicture(icon: node.icon, size: node.naturalSize)
        case .button where !node.children.isEmpty: NodeButton(node: node, look: nil, label: AnyView(NodeBox(children: node.children, style: style, tree: tree)))
        case .field where node.isSearch: NodeSearch()
        case .toggle: NodeSwitch(node: node, look: SpotPart.Look(style: style))
        case .choice: NodeChoice(node: node, look: SpotPart.Look(style: style))
        case .field, .slider, .hotkey: NodeField(node: node, look: SpotPart.Look(style: style))
        case .button: NodeButton(node: node, look: SpotPart.Look(style: style))
        case .number, .series: NodeNumber(node: node, look: SpotPart.Look(style: style))
        case .items: NodeItems(size: node.naturalSize)
        default:
            if let source = node.source { NodeSpotView(id: node.id, values: node.values, source: source) }
        }
    }
}
