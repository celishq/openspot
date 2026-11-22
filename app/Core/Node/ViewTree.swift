import Foundation

public struct ViewTree: Equatable, Sendable {
    public static let empty = ViewTree(blocks: [], root: nil, kinds: [])

    public let style: Style
    public let isWritten: Bool
    public private(set) var children: [String] = []
    public private(set) var nodes: [String: ViewNode] = [:]
    public private(set) var faults: [String] = []
    public private(set) var places: Set<Style.Variant> = []
    public private(set) var listed: Set<String> = []
    public private(set) var holdsItems = false

    public func node(_ id: String) -> ViewNode? {
        nodes[id]
    }

    public func draws(on size: SpotSize) -> Bool {
        !places.isDisjoint(with: Style.Variant.card(size))
    }

    public var drawsOnBar: Bool {
        places.contains(.bar)
    }

    public func shown(in active: Set<Style.Variant>) -> [String] {
        guard style.resolved(for: active).isHidden != true else { return [] }
        var shown: [String] = []
        var next = Array(children.reversed())
        while let id = next.popLast() {
            guard let node = nodes[id], node.style.resolved(for: active).isHidden != true else { continue }
            shown.append(id)
            next += node.children.reversed()
        }
        return shown
    }

    static func id(of block: TextBlock, in kinds: [BlockKind]) -> String? {
        guard let first = block.fields.first, !first.value.isEmpty, first.key != BlockKind.option,
              FrameRoot.isKind(first.key, in: kinds),
              first.key != BlockKind.button.word || block.value("scope") == nil else { return nil }
        return first.value
    }

    func unwritten(showing blocks: [TextBlock], root: TextBlock, kinds: [BlockKind]) -> ViewTree {
        var shown = ViewTree(blocks: blocks, root: root, kinds: kinds, isWritten: false)
        shown.faults = faults
        return shown
    }

    init(blocks: [TextBlock], root: TextBlock?, kinds: [BlockKind], styles: StyleCache = .shared, isWritten written: Bool? = nil) {
        let rootClasses = root?.value(ViewNode.classKey)
        style = rootClasses.map(styles.style(of:)) ?? Style()
        faults += style.unknown.map { "the root has an unknown class: \($0)" }
        var order: [String] = []
        var found: [String: TextBlock] = [:]
        for block in blocks {
            guard let id = Self.id(of: block, in: kinds), found[id] == nil else { continue }
            found[id] = block
            order.append(id)
        }
        let named = order.filter { id in found[id]?.value(ViewNode.parentKey).map { $0 != id && found[$0] != nil } ?? false }
        isWritten = written ?? (rootClasses != nil || !named.isEmpty || order.contains { found[$0]?.fields.first?.key == BlockKind.box || found[$0]?.value(ViewNode.classKey) != nil })
        var parents: [String: String] = [:]
        for id in order {
            guard let parent = found[id]?.value(ViewNode.parentKey) else { continue }
            if found[parent] != nil {
                parents[id] = parent
            } else if isWritten {
                faults.append("the part \(id) names the parent \(parent), which no part has")
            }
        }
        for id in order {
            var seen: Set<String> = []
            var next = parents[id]
            while let at = next, seen.insert(at).inserted {
                if at == id {
                    parents[id] = nil
                    faults.append("the part \(id) sits inside itself")
                    break
                }
                next = parents[at]
            }
        }
        var held: [String: [String]] = [:]
        for id in order {
            if let parent = parents[id] { held[parent, default: []].append(id) } else { children.append(id) }
        }
        for id in order {
            guard let block = found[id], let kind = block.fields.first?.key else { continue }
            let style = block.value(ViewNode.classKey).map(styles.style(of:)) ?? Style()
            faults += style.unknown.map { "the part \(id) has an unknown class: \($0)" }
            nodes[id] = ViewNode(id: id, kind: kind, parent: parents[id], block: block, style: style, children: held[id] ?? [], part: BlockKind.of(block, in: kinds))
            places.formUnion(style.named)
        }
        holdsItems = nodes.values.contains { $0.kind == BlockKind.items }
        listed = Set(nodes.values.filter { $0.parent.flatMap { nodes[$0] }?.kind == BlockKind.items }.map(\.id))
        places.formUnion(self.style.named)
    }
}
