import Foundation

struct AccountFrame {
    enum Look {
        case plain, main, close, picked
    }

    private static let divider = "-"

    private var head: [TextBlock.Field] = []
    private var blocks: [TextBlock] = []
    private var lines: [[String]] = []
    private var classes: [String: String] = [:]

    var text: String {
        let end = endButtons
        var shown: [TextBlock] = [RootKey.block([.init(key: "class", value: end == nil ? "gap-part" : "gap-group")] + head)]
        if end != nil {
            shown.append(TextBlock(fields: [.init(key: "box", value: "top"), .init(key: "class", value: "gap-part")]))
            shown.append(TextBlock(fields: [.init(key: "box", value: "end"), .init(key: "class", value: "gap-part")]))
        }
        var placed = Set<String>()
        for (index, line) in lines.enumerated() {
            let group = end.map { index < $0 ? "top" : "end" }
            if line == [Self.divider] {
                shown.append(placing(TextBlock(fields: [.init(key: "box", value: "line-\(index)"), .init(key: "class", value: "h-px bg-tile")]), in: group))
                continue
            }
            let row = line.count > 1 ? "row-\(index)" : nil
            if let row {
                shown.append(placing(TextBlock(fields: [.init(key: "box", value: row), .init(key: "class", value: "grid grid-cols-\(line.count) gap-part")]), in: group))
            }
            for id in line {
                guard let block = blocks.first(where: { $0.fields.first?.value == id }) else { continue }
                placed.insert(id)
                shown.append(placing(block, in: row ?? group))
            }
        }
        shown += blocks.filter { !placed.contains($0.fields.first?.value ?? "") }
        return shown.map(\.text).joined(separator: "\n")
    }

    private var endButtons: Int? {
        let isButtons = { (line: [String]) in
            line != [Self.divider] && line.allSatisfy { id in blocks.contains { $0.fields.first?.key == "button" && $0.fields.first?.value == id } }
        }
        guard let last = lines.lastIndex(where: { !isButtons($0) }) else { return nil }
        return last + 1 < lines.count ? last + 1 : nil
    }

    private func placing(_ block: TextBlock, in parent: String?) -> TextBlock {
        guard let first = block.fields.first else { return block }
        var added: [TextBlock.Field] = []
        if let parent { added.append(.init(key: "parent", value: parent)) }
        if let style = classes[first.value] { added.append(.init(key: "class", value: style)) }
        return TextBlock(fields: [first] + added + block.fields.dropFirst())
    }

    mutating func head(_ key: String, _ value: String) {
        head.append(.init(key: key, value: value))
    }

    mutating func rows(_ rows: String...) {
        for row in rows {
            var ids: [String] = []
            for id in row.split(separator: " ").map(String.init) where !ids.contains(id) { ids.append(id) }
            lines.append(ids)
        }
    }

    mutating func style(_ id: String, _ style: String) {
        classes[id] = style
    }

    mutating func wordRows() {
        for first in stride(from: 1, through: AccountPhrase.wordCount, by: 2) { rows("w\(first) w\(first + 1)") }
    }

    mutating func block(_ values: [String: String], order: [String]) {
        blocks.append(TextBlock(fields: order.compactMap { key in values[key].map { .init(key: key, value: $0) } }))
    }

    mutating func line(_ id: String, _ title: String, icon: String? = nil, tone: String? = nil, detail: String? = nil) {
        var fields: [TextBlock.Field] = [.init(key: "text", value: id), .init(key: "class", value: "bg-tile rounded-inner p-3"), .init(key: "title", value: title)]
        if let icon { fields.append(.init(key: "icon", value: icon)) }
        if let tone { fields.append(.init(key: "tone", value: tone)) }
        if let detail { fields.append(.init(key: "detail", value: detail)) }
        blocks.append(TextBlock(fields: fields))
    }

    mutating func word(_ place: Int, _ word: String, tone: String? = nil) {
        line("w\(place)", word, icon: "\(place).circle", tone: tone)
    }

    mutating func button(_ id: String, _ title: String, _ look: Look = .plain) {
        var fields: [TextBlock.Field] = [.init(key: "button", value: id), .init(key: "title", value: title)]
        switch look {
        case .plain: fields.append(.init(key: "close", value: "false"))
        case .main: fields += [.init(key: "shortcut", value: "cmd+return"), .init(key: "look", value: "strong"), .init(key: "close", value: "false")]
        case .close: break
        case .picked: fields += [.init(key: "look", value: "strong"), .init(key: "close", value: "false")]
        }
        blocks.append(TextBlock(fields: fields))
    }

    mutating func howAction() {
        blocks.append(TextBlock(fields: [.init(key: "button", value: "how"), .init(key: "title", value: "How it works"), .init(key: "scope", value: "spot"), .init(key: "close", value: "false")]))
    }
}
