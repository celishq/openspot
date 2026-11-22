import CoreGraphics
import Foundation

extension ViewTree {
    public func height(in width: CGFloat, parts: [SpotPart], variants: Set<Style.Variant> = [.sheet]) -> CGFloat? {
        let shown = Set(shown(in: variants))
        let root = style.resolved(for: variants)
        let fills = shown.contains { id in
            guard let node = nodes[id] else { return false }
            let holder = node.parent.flatMap { nodes[$0] }?.style.resolved(for: variants) ?? root
            let style = node.style.resolved(for: variants)
            return node.kind == BlockKind.items || style.grows == true && ((holder.arrangement ?? .column) == .column || style.isAbsolute)
        }
        guard !fills else { return nil }
        let lines = Dictionary(parts.map { ($0.id, $0.flatLines) }) { first, _ in first }
        return measure(children, style: root, in: variants, shown: shown, lines: lines, words: [:], width: width).height
    }

    func frames(in width: CGFloat, room: CGFloat, parts: [SpotPart], words: [String: CGFloat]) -> [String: CGRect] {
        let variants: Set<Style.Variant> = [.sheet]
        let shown = Set(shown(in: variants))
        let root = style.resolved(for: variants)
        let lines = Dictionary(parts.map { ($0.id, $0.flatLines) }) { first, _ in first }
        let natural = measure(children, style: root, in: variants, shown: shown, lines: lines, words: words, width: width).height
        let height = height(in: width, parts: parts) ?? max(natural, room)
        var frames: [String: CGRect] = [:]
        lay(children, style: root, in: variants, shown: shown, lines: lines, words: words, size: CGSize(width: width, height: height), into: &frames)
        return frames
    }

    private func lay(_ ids: [String], style: Style, in variants: Set<Style.Variant>, shown: Set<String>, lines: [String: Int], words: [String: CGFloat], size: CGSize, into frames: inout [String: CGRect]) {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let placed = ids.filter(shown.contains).compactMap { nodes[$0] }
        let children = placed.map { node in
            BoxLayout.Child(style: node.style.resolved(for: variants)) { width, _ in measure(node, in: variants, shown: shown, lines: lines, words: words, width: width) }
        }
        let room = CGSize(width: size.width - side(.left) - side(.right), height: size.height - side(.top) - side(.bottom))
        let layout = BoxLayout(style: style).place(children, width: room.width, height: room.height)
        for (node, frame) in zip(placed, layout.frames) {
            frames[node.id] = frame
            guard node.kind != BlockKind.items, node.kind == BlockKind.box || !node.children.isEmpty else { continue }
            lay(node.children, style: node.style.resolved(for: variants), in: variants, shown: shown, lines: lines, words: words, size: frame.size, into: &frames)
        }
    }

    private func measure(_ ids: [String], style: Style, in variants: Set<Style.Variant>, shown: Set<String>, lines: [String: Int], words: [String: CGFloat], width: CGFloat?) -> CGSize {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let across = side(.left) + side(.right)
        let down = side(.top) + side(.bottom)
        let children = ids.filter(shown.contains).compactMap { nodes[$0] }.map { node in
            BoxLayout.Child(style: node.style.resolved(for: variants)) { width, _ in measure(node, in: variants, shown: shown, lines: lines, words: words, width: width) }
        }
        let size = BoxLayout(style: style).place(children, width: width.map { $0 - across }, height: nil).size
        return CGSize(width: size.width + across, height: size.height + down)
    }

    private func measure(_ node: ViewNode, in variants: Set<Style.Variant>, shown: Set<String>, lines: [String: Int], words: [String: CGFloat], width: CGFloat?) -> CGSize {
        let style = node.style.resolved(for: variants)
        if node.kind != BlockKind.items, node.kind == BlockKind.box || !node.children.isEmpty {
            return measure(node.children, style: style, in: variants, shown: shown, lines: lines, words: words, width: width)
        }
        let height: CGFloat = switch node.kind {
        case "text": textHeight(node, style)
        case "icon": SpotTokens.listIconSize
        case "picture": SpotTokens.cell
        default: node.source == nil ? Self.rowsHeight(lines[node.id] ?? 1) : SpotTokens.cell
        }
        return CGSize(width: width ?? words[node.id] ?? 0, height: height)
    }

    private static func rowsHeight(_ lines: Int) -> CGFloat {
        SpotTokens.listRow * CGFloat(lines) + SpotTokens.partGap * CGFloat(lines - 1)
    }

    func textHeight(_ node: ViewNode, _ style: Style) -> CGFloat {
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
