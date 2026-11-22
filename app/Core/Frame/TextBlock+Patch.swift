import Foundation

extension TextBlock {
    static func patching(_ base: [TextBlock], with blocks: [TextBlock], id: (TextBlock) -> String?) -> [TextBlock] {
        var merged = base
        for block in blocks {
            if let key = id(block), let index = merged.firstIndex(where: { id($0) == key }) {
                merged[index] = merged[index].patched(by: block)
            } else {
                merged.append(block)
            }
        }
        return merged
    }

    func patched(by block: TextBlock) -> TextBlock {
        let parent = ViewNode.parentKey
        guard fields.first?.key == block.fields.first?.key else {
            guard !block.fields.contains(where: { $0.key == parent }), let kept = fields.first(where: { $0.key == parent }) else { return block }
            return TextBlock(fields: block.fields + [kept], firstLine: block.firstLine, children: block.children)
        }
        let named = Set(block.fields.map(\.key))
        var written: Set<String> = []
        var next: [Field] = []
        for field in addingPoints().fields {
            if !named.contains(field.key) {
                next.append(field)
            } else if written.insert(field.key).inserted {
                next += block.fields.filter { $0.key == field.key }
            }
        }
        next += block.fields.filter { !written.contains($0.key) }
        return TextBlock(fields: next, firstLine: block.firstLine, children: block.children.isEmpty ? children : block.children).addingPoints()
    }
}
