import Foundation

extension ViewTree {
    public func follows(_ states: Set<Style.Variant>, at node: ViewNode) -> Bool {
        !node.style.named.isDisjoint(with: states) || (node.kind == BlockKind.button.word && !places.isDisjoint(with: states))
    }

    public func tracksHover(_ node: ViewNode) -> Bool {
        if node.style.named.contains(.hover) { return true }
        guard node.kind == BlockKind.button.word else { return false }
        var next = node.children
        while let id = next.popLast() {
            guard let child = nodes[id] else { continue }
            if child.style.named.contains(.hover) { return true }
            next += child.children
        }
        return false
    }

    public func states(in variants: Set<Style.Variant>, pressed: Bool, hovered: Bool, selected: Bool) -> Set<Style.Variant> {
        variants.union(pressed ? [.pressed] : []).union(hovered ? [.hover] : []).union(selected ? [.selected, .focus] : [])
    }

    public func isSelected(_ node: ViewNode, selection: () -> String?) -> Bool {
        guard follows([.selected, .focus], at: node) else { return false }
        let id = selection()
        return node.kind == BlockKind.items ? id == nil : id == node.id
    }
}
