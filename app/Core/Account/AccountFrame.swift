import Foundation

struct AccountFrame {
    enum Look {
        case plain, main, close, picked
    }

    private var head: [TextBlock.Field] = []
    private var blocks: [TextBlock] = []

    var text: String {
        ([RootKey.block(head)] + blocks).map(\.text).joined(separator: "\n")
    }

    mutating func head(_ key: String, _ value: String) {
        head.append(.init(key: key, value: value))
    }

    mutating func grid(_ lines: String...) {
        for line in lines { head("grid", line) }
    }

    mutating func wordGrid() {
        for first in stride(from: 1, through: AccountPhrase.wordCount, by: 2) { grid("w\(first) w\(first + 1)") }
    }

    mutating func block(_ values: [String: String], order: [String]) {
        blocks.append(TextBlock(fields: order.compactMap { key in values[key].map { .init(key: key, value: $0) } }))
    }

    mutating func line(_ id: String, _ title: String, icon: String? = nil, tone: String? = nil, detail: String? = nil) {
        var fields: [TextBlock.Field] = [.init(key: "text", value: id), .init(key: "look", value: "tile"), .init(key: "title", value: title)]
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
        case .plain: break
        case .main: fields += [.init(key: "shortcut", value: "cmd+return"), .init(key: "look", value: "strong")]
        case .close: fields.append(.init(key: "close", value: "true"))
        case .picked: fields.append(.init(key: "look", value: "strong"))
        }
        blocks.append(TextBlock(fields: fields))
    }

    mutating func howAction() {
        blocks.append(TextBlock(fields: [.init(key: "button", value: "how"), .init(key: "title", value: "How it works"), .init(key: "scope", value: "spot")]))
    }
}
