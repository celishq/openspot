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
    private(set) var order: [String] = []

    public func node(_ id: String) -> ViewNode? {
        nodes[id]
    }

    public func draws(on size: SpotSize) -> Bool {
        !places.isDisjoint(with: Style.Variant.card(size))
    }

    func group(of id: String) -> String? {
        guard let box = nodes[id]?.parent.flatMap({ nodes[$0] }), box.kind == BlockKind.box, listed.contains(box.id) else { return nil }
        return box.block.value("title")
    }

    public func partIDs(shownIn places: [Set<Style.Variant>]) -> [String] {
        let shown = Set(places.flatMap(shown(in:)))
        return order.filter { id in
            guard shown.contains(id), let node = nodes[id], node.part != nil else { return false }
            return node.kind == BlockKind.choice.word || isWritten && !listed.contains(id)
        }
    }

    mutating func set(_ value: String, of id: String) {
        nodes[id]?.part?.set(value)
    }

    func changedParts(from other: ViewTree) -> [String]? {
        var same = other
        for (id, node) in nodes { same.nodes[id]?.part = node.part }
        guard same == self else { return nil }
        let changed = order.filter { nodes[$0]?.part != other.nodes[$0]?.part }
        return changed.isEmpty ? nil : changed
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
        guard block.fields.first?.key != BlockKind.button.word || block.value("scope") == nil else { return nil }
        return patchID(of: block, in: kinds)
    }

    static func patchID(of block: TextBlock, in kinds: [BlockKind]) -> String? {
        guard let first = block.fields.first, !first.value.isEmpty, first.key != BlockKind.option,
              FrameRoot.isKind(first.key, in: kinds) else { return nil }
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
        var found: [String: TextBlock] = [:]
        for block in blocks {
            guard let id = Self.id(of: block, in: kinds), found[id] == nil else { continue }
            found[id] = block
            order.append(id)
        }
        let named = order.filter { id in found[id]?.value(ViewNode.parentKey).map { $0 != id && found[$0] != nil } ?? false }
        isWritten = written ?? (rootClasses != nil || order.contains { found[$0]?.fields.first?.key == BlockKind.items })
        if written == nil, !isWritten {
            faults += order.filter { found[$0]?.fields.first?.key == BlockKind.box || named.contains($0) }.map { "the part \($0) needs a layout, so give the root a class" }
        }
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
            nodes[id] = ViewNode(id: id, kind: kind, parent: parents[id], block: block, style: style, children: held[id] ?? [], blockKind: BlockKind.of(block, in: kinds))
            places.formUnion(style.named)
        }
        holdsItems = nodes.values.contains { $0.kind == BlockKind.items }
        let tree = nodes
        let holder = { (id: String?) in id.flatMap { tree[$0] } }
        listed = Set(nodes.values.filter { node in
            guard let parent = holder(node.parent) else { return false }
            return parent.kind == BlockKind.items || parent.kind == BlockKind.box && holder(parent.parent)?.kind == BlockKind.items
        }.map(\.id))
        for (id, node) in nodes where node.isSearch || node.part?.isPressable == true && (!isWritten || listed.contains(id)) {
            nodes[id]?.part = nil
        }
        for id in order {
            guard let node = nodes[id], let parent = node.parent, let container = nodes[parent] else { continue }
            if node.kind == BlockKind.box, container.kind == BlockKind.box, listed.contains(id) {
                faults.append("the box \(id) sits inside the group \(parent), so it and the blocks inside it do not show. A group is one level deep")
            } else if listed.contains(parent), container.kind != BlockKind.box {
                faults.append("the block \(id) sits inside the item \(parent), so it does not show. An item is one block")
            }
        }
        places.formUnion(self.style.named)
    }
}
