import Foundation

extension TextBlock {
    static func patching(_ base: [TextBlock], with blocks: [TextBlock], id: (TextBlock) -> String?) -> [TextBlock] {
        var merged = base
        var places = firstPlaces(of: merged, id: id)
        for block in blocks {
            let key = id(block)
            if let key, let index = places[key] {
                merged[index] = merged[index].patched(by: block)
                if id(merged[index]) != key { places = firstPlaces(of: merged, id: id) }
            } else {
                if let key { places[key] = merged.count }
                merged.append(block)
            }
        }
        return merged
    }

    private static func firstPlaces(of blocks: [TextBlock], id: (TextBlock) -> String?) -> [String: Int] {
        var places: [String: Int] = [:]
        for (index, block) in blocks.enumerated() {
            if let key = id(block), places[key] == nil { places[key] = index }
        }
        return places
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
