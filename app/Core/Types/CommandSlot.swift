import Foundation

struct CommandSlot: Equatable, Sendable {
    enum Kind: String, Sendable {
        case word, words, pairs, flag, option
    }

    let name: String
    let kind: Kind
    let isRequired: Bool
    let option: String?
    var isRepeated = false

    var key: String {
        Self.identifier(name.split(separator: "-").map(String.init))
    }

    var isPositional: Bool {
        option == nil
    }

    var spec: [String: Any] {
        var spec: [String: Any] = ["key": key, "kind": kind.rawValue]
        if let option { spec["option"] = option }
        return spec
    }

    static func identifier(_ words: [String]) -> String {
        let parts = words.flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init) }
        guard let first = parts.first?.lowercased() else { return "call" }
        return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    static func slots(of form: String) -> [CommandSlot] {
        var slots: [CommandSlot] = []
        for group in groups(of: joinedNames(form)) {
            switch group {
            case .word(let word):
                slots.append(positional(word, repeats: word.hasSuffix("..."), isRepeated: word.hasSuffix("..."), isRequired: true))
            case .optional(let inside, let repeats):
                let choices = inside.split(separator: "|").map { $0.split(separator: " ").map(String.init) }
                for choice in choices {
                    guard let option = choice.first, option.hasPrefix("--") else { continue }
                    slots.append(CommandSlot(name: String(option.dropFirst(2)), kind: choice.count > 1 ? .option : .flag, isRequired: false, option: option, isRepeated: repeats))
                }
                let words = choices.filter { $0.first?.hasPrefix("--") == false }
                guard let first = words.first?.first else { continue }
                slots.append(positional(words.count > 1 ? "value" : first, repeats: repeats || inside.hasSuffix("..."), isRepeated: repeats, isRequired: false))
            }
        }
        return slots
    }

    private enum Group {
        case word(String)
        case optional(String, repeats: Bool)
    }

    private static func joinedNames(_ form: String) -> String {
        var characters = Array(form)
        var open: Int?
        for index in characters.indices {
            switch characters[index] {
            case "<": open = index
            case ">":
                if let start = open {
                    for inner in (start + 1)..<index where characters[inner] == " " { characters[inner] = "-" }
                }
                open = nil
            default: break
            }
        }
        return String(characters)
    }

    private static func groups(of text: String) -> [Group] {
        let characters = Array(text)
        var groups: [Group] = []
        var index = 0
        while index < characters.count {
            if characters[index].isWhitespace {
                index += 1
            } else if characters[index] == "[", let close = closing(characters, after: index) {
                let repeats = characters[(close + 1)...].starts(with: "...")
                groups.append(.optional(String(characters[(index + 1)..<close]), repeats: repeats))
                index = close + 1 + (repeats ? 3 : 0)
            } else {
                let start = index
                while index < characters.count, !characters[index].isWhitespace { index += 1 }
                groups.append(.word(String(characters[start..<index])))
            }
        }
        return groups
    }

    private static func closing(_ characters: [Character], after open: Int) -> Int? {
        var index = open + 1
        while index < characters.count {
            switch characters[index] {
            case "]": return index
            case "[":
                guard let inner = characters[(index + 1)...].firstIndex(of: "]") else { return nil }
                index = inner + 1
            default: index += 1
            }
        }
        return nil
    }

    static func schema(of slots: [CommandSlot]) -> [String: Any] {
        var properties: [String: Any] = [:]
        for slot in slots {
            let one: [String: Any] = ["type": slot.kind == .flag ? "boolean" : "string"]
            properties[slot.name] = slot.isRepeated || slot.kind == .words || slot.kind == .pairs ? ["type": "array", "items": one] : one
        }
        return ["type": "object", "properties": properties, "required": slots.filter(\.isRequired).map(\.name)]
    }

    private static func positional(_ word: String, repeats: Bool, isRepeated: Bool, isRequired: Bool) -> CommandSlot {
        let name = word.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let isPairs = repeats && (name == "input" || name.contains("="))
        return CommandSlot(name: isPairs ? "input" : name, kind: isPairs ? .pairs : repeats ? .words : .word, isRequired: isRequired, option: nil, isRepeated: isRepeated)
    }
}
