import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotNodeVariants: Set<Style.Variant> = [.sheet]
    @Entry var spotPictureTimes: [String: Double] = [:]
    @Entry var spotNodeSend: ((String, String) -> Void)?
}

struct NodeView: View {
    let node: ViewNode
    let tree: ViewTree
    @Environment(\.spotNodeVariants) private var variants

    var body: some View {
        let style = node.style.resolved(for: variants)
        if style.isHidden != true {
            content(style)
                .modifier(NodeLook(style: style))
                .layoutValue(key: NodeSlot.self, value: style)
        }
    }

    @ViewBuilder
    private func content(_ style: Style) -> some View {
        switch node.kind {
        case BlockKind.box: NodeBox(children: node.children, style: style, tree: tree)
        case "text": NodeText(title: node.title ?? node.value, detail: node.detail, tone: node.tone, symbol: node.icon?.symbol)
        case "icon": NodeIcon(icon: node.icon)
        case "picture": NodePicture(path: node.icon?.image)
        default:
            if let source = node.source { NodeSpotView(id: node.id, values: node.values, source: source) }
        }
    }
}
