import CoreGraphics
import Foundation

extension ViewTree {
    public func height(in width: CGFloat, parts: [SpotPart]) -> CGFloat? {
        let shown = Set(shown(in: [.sheet]))
        let root = style.resolved(for: [.sheet])
        let fills = shown.contains { id in
            guard let node = nodes[id] else { return false }
            let holder = node.parent.flatMap { nodes[$0] }?.style.resolved(for: [.sheet]) ?? root
            return node.kind == BlockKind.items || node.style.resolved(for: [.sheet]).grows == true && (holder.arrangement ?? .column) == .column
        }
        guard !fills else { return nil }
        let lines = Dictionary(parts.map { ($0.id, $0.flatLines) }) { first, _ in first }
        return measure(children, style: root, shown: shown, lines: lines, width: width).height
    }

    private func measure(_ ids: [String], style: Style, shown: Set<String>, lines: [String: Int], width: CGFloat?) -> CGSize {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let across = side(.left) + side(.right)
        let down = side(.top) + side(.bottom)
        let children = ids.filter(shown.contains).compactMap { nodes[$0] }.map { node in
            BoxLayout.Child(style: node.style.resolved(for: [.sheet])) { width, _ in measure(node, shown: shown, lines: lines, width: width) }
        }
        let size = BoxLayout(style: style).place(children, width: width.map { $0 - across }, height: nil).size
        return CGSize(width: size.width + across, height: size.height + down)
    }

    private func measure(_ node: ViewNode, shown: Set<String>, lines: [String: Int], width: CGFloat?) -> CGSize {
        let style = node.style.resolved(for: [.sheet])
        if node.kind == BlockKind.box || !node.children.isEmpty {
            return measure(node.children, style: style, shown: shown, lines: lines, width: width)
        }
        let height: CGFloat = switch node.kind {
        case "text": textHeight(node, style)
        case "icon": SpotTokens.listIconSize
        case "picture": SpotTokens.cell
        default: node.source == nil ? SpotTokens.listRow * CGFloat(lines[node.id] ?? 1) : SpotTokens.cell
        }
        return CGSize(width: width ?? 0, height: height)
    }

    private func textHeight(_ node: ViewNode, _ style: Style) -> CGFloat {
        let type = SpotTokens.layout.type
        let face: Double? = switch style.font {
        case .title, .section: type.title
        case .detail: type.detail
        case .metric, .value: nil
        case nil: type.body
        }
        guard let face else { return SpotTokens.listRow }
        let title = CGFloat(face) + SpotTokens.textLeading
        guard node.detail != nil else { return title }
        return title + SpotTokens.textLineGap + CGFloat(type.detail) + SpotTokens.textLeading
    }
}
