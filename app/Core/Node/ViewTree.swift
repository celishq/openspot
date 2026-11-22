import Foundation

public struct ViewTree: Equatable, Sendable {
    public static let empty = ViewTree(blocks: [], root: nil, kinds: [])

    public let style: Style
    public let isWritten: Bool
    public private(set) var children: [String] = []
    public private(set) var nodes: [String: ViewNode] = [:]
    public private(set) var faults: [String] = []

    public func node(_ id: String) -> ViewNode? {
        nodes[id]
    }

    init(blocks: [TextBlock], root: TextBlock?, kinds: [BlockKind], styles: StyleCache = .shared) {
        let rootClasses = root?.value(ViewNode.classKey)
        style = rootClasses.map(styles.style(of:)) ?? Style()
        faults += style.unknown.map { "the root has an unknown class: \($0)" }
        var order: [String] = []
        var found: [String: TextBlock] = [:]
        for block in blocks {
            guard let first = block.fields.first, !first.value.isEmpty, first.key != BlockKind.option,
                  FrameRoot.isKind(first.key, in: kinds), found[first.value] == nil else { continue }
            found[first.value] = block
            order.append(first.value)
        }
        let named = order.filter { id in found[id]?.value(ViewNode.parentKey).map { $0 != id && found[$0] != nil } ?? false }
        isWritten = rootClasses != nil || !named.isEmpty || order.contains { found[$0]?.fields.first?.key == BlockKind.box }
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
            nodes[id] = ViewNode(id: id, kind: kind, parent: parents[id], block: block, style: style, children: held[id] ?? [], source: BlockKind.of(block, in: kinds)?.source)
        }
    }
}
