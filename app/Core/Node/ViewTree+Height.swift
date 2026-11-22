import CoreGraphics
import Foundation

extension ViewTree {
    private static let letterShare: CGFloat = 0.5

    public func height(in width: CGFloat, variants: Set<Style.Variant> = [.sheet]) -> CGFloat? {
        let shown = Set(shown(in: variants))
        let root = style.resolved(for: variants)
        let fills = shown.contains { id in
            guard let node = nodes[id] else { return false }
            let holder = node.parent.flatMap { nodes[$0] }?.style.resolved(for: variants) ?? root
            let style = node.style.resolved(for: variants)
            return node.kind == BlockKind.items || style.grows == true && ((holder.arrangement ?? .column) == .column || style.isAbsolute)
        }
        guard !fills else { return nil }
        return measure(children, style: root, in: variants, shown: shown, words: [:], width: width).height
    }

    func frames(in width: CGFloat, room: CGFloat, words: [String: CGFloat]) -> [String: CGRect] {
        let variants: Set<Style.Variant> = [.sheet]
        let shown = Set(shown(in: variants))
        let root = style.resolved(for: variants)
        let height = height(in: width) ?? max(measure(children, style: root, in: variants, shown: shown, words: words, width: width).height, room)
        var frames: [String: CGRect] = [:]
        lay(children, style: root, in: variants, shown: shown, words: words, size: CGSize(width: width, height: height), into: &frames)
        return frames
    }

    private func lay(_ ids: [String], style: Style, in variants: Set<Style.Variant>, shown: Set<String>, words: [String: CGFloat], size: CGSize, into frames: inout [String: CGRect]) {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let placed = ids.filter(shown.contains).compactMap { nodes[$0] }
        let children = placed.map { node in
            BoxLayout.Child(style: node.style.resolved(for: variants)) { width, _ in measure(node, in: variants, shown: shown, words: words, width: width) }
        }
        let room = CGSize(width: size.width - side(.left) - side(.right), height: size.height - side(.top) - side(.bottom))
        let layout = BoxLayout(style: style).place(children, width: room.width, height: room.height)
        for (node, frame) in zip(placed, layout.frames) {
            frames[node.id] = frame
            guard node.kind != BlockKind.items, node.kind == BlockKind.box || !node.children.isEmpty else { continue }
            lay(node.children, style: node.style.resolved(for: variants), in: variants, shown: shown, words: words, size: frame.size, into: &frames)
        }
    }

    private func measure(_ ids: [String], style: Style, in variants: Set<Style.Variant>, shown: Set<String>, words: [String: CGFloat], width: CGFloat?) -> CGSize {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let across = side(.left) + side(.right)
        let down = side(.top) + side(.bottom)
        let children = ids.filter(shown.contains).compactMap { nodes[$0] }.map { node in
            BoxLayout.Child(style: node.style.resolved(for: variants)) { width, _ in measure(node, in: variants, shown: shown, words: words, width: width) }
        }
        let size = BoxLayout(style: style).place(children, width: width.map { $0 - across }, height: nil).size
        return CGSize(width: size.width + across, height: size.height + down)
    }

    private func measure(_ node: ViewNode, in variants: Set<Style.Variant>, shown: Set<String>, words: [String: CGFloat], width: CGFloat?) -> CGSize {
        let style = node.style.resolved(for: variants)
        if node.kind != BlockKind.items, node.kind == BlockKind.box || !node.children.isEmpty {
            return measure(node.children, style: style, in: variants, shown: shown, words: words, width: width)
        }
        let across = (style.padding[.left]?.points(of: 0) ?? 0) + (style.padding[.right]?.points(of: 0) ?? 0)
        return CGSize(width: width ?? (words[node.id] ?? 0) + across, height: leafHeight(node, style, width: width))
    }

    func leafHeight(_ node: ViewNode, _ style: Style, width: CGFloat?) -> CGFloat {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        let room = width.map { max($0 - side(.left) - side(.right), 0) }
        let content = node.kind == BlockKind.text.word ? textHeight(node, style, width: room) : node.naturalSize.height
        return content + side(.top) + side(.bottom)
    }

    private func textHeight(_ node: ViewNode, _ style: Style, width: CGFloat?) -> CGFloat {
        let type = SpotTokens.layout.type
        let face: Double? = switch style.font {
        case .title, .section: type.title
        case .detail: type.detail
        case .metric, .value: nil
        case nil: type.body
        }
        guard let face else { return SpotTokens.listRow }
        let room = width.map { node.icon?.symbol == nil ? $0 : $0 - SpotTokens.listIconSize - SpotTokens.partLineGap }
        let limit = style.truncates ? 1 : style.lineLimit
        let titleLines = (node.title ?? node.value).map { Self.lines(of: $0, face: face, room: room, limit: limit) } ?? 1
        let title = CGFloat(titleLines) * (CGFloat(face) + SpotTokens.textLeading)
        guard let detail = node.detail else { return title }
        let detailLines = Self.lines(of: detail, face: type.detail, room: room, limit: limit)
        return title + SpotTokens.textLineGap + CGFloat(detailLines) * (CGFloat(type.detail) + SpotTokens.textLeading)
    }

    private static func lines(of text: String, face: Double, room: CGFloat?, limit: Int?) -> Int {
        guard let room, room > 0 else { return 1 }
        let letter = CGFloat(face) * letterShare
        var count = 0
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var used: CGFloat = 0
            count += 1
            for word in paragraph.split(separator: " ") {
                let width = CGFloat(word.count) * letter
                if used > 0, used + letter + width > room {
                    count += 1
                    used = 0
                }
                if used == 0, width > room {
                    count += Int((width / room).rounded(.up)) - 1
                    used = width.truncatingRemainder(dividingBy: room)
                } else {
                    used += (used > 0 ? letter : 0) + width
                }
            }
        }
        return min(max(count, 1), limit ?? .max)
    }
}
