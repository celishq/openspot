import Foundation

extension ViewTree {
    public func follows(_ states: Set<Style.Variant>, at node: ViewNode) -> Bool {
        !node.style.named.isDisjoint(with: states) || (node.kind == BlockKind.button.word && !places.isDisjoint(with: states))
    }

    public func isSelected(_ node: ViewNode, selection: () -> String?) -> Bool {
        guard follows([.selected, .focus], at: node) else { return false }
        let id = selection()
        return node.kind == BlockKind.items ? id == nil : id == node.id
    }
}
