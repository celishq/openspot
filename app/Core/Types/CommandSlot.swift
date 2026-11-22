import Foundation

struct CommandSlot: Equatable, Sendable {
    enum Kind: String, Sendable {
        case word, words, pairs, flag, option
    }

    let name: String
    let kind: Kind
    let isRequired: Bool
    let option: String?

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
        let named = (try? NSRegularExpression(pattern: "<([^<>]*)>")).map { expression in
            var text = form
            for match in expression.matches(in: form, range: NSRange(form.startIndex..., in: form)).reversed() {
                guard let range = Range(match.range, in: text) else { continue }
                text.replaceSubrange(range, with: text[range].replacingOccurrences(of: " ", with: "-"))
            }
            return text
        } ?? form
        var slots: [CommandSlot] = []
        let groups = try? NSRegularExpression(pattern: #"\[((?:[^\[\]]|\[[^\]]*\])*)\](\.\.\.)?|(\S+)"#)
        for match in groups?.matches(in: named, range: NSRange(named.startIndex..., in: named)) ?? [] {
            let text = { (index: Int) in Range(match.range(at: index), in: named).map { String(named[$0]) } }
            if let word = text(3) {
                slots.append(positional(word, repeats: word.hasSuffix("..."), isRequired: true))
                continue
            }
            let inside = text(1) ?? ""
            let choices = inside.split(separator: "|").map { $0.split(separator: " ").map(String.init) }
            if let first = choices.first?.first, first.hasPrefix("--") {
                for choice in choices {
                    guard let option = choice.first, option.hasPrefix("--") else { continue }
                    slots.append(CommandSlot(name: String(option.dropFirst(2)), kind: choice.count > 1 ? .option : .flag, isRequired: false, option: option))
                }
                continue
            }
            let word = choices.count > 1 ? "value" : inside.split(separator: " ").first.map(String.init) ?? "value"
            slots.append(positional(word, repeats: text(2) != nil || inside.hasSuffix("..."), isRequired: false))
        }
        return slots
    }

    private static func positional(_ word: String, repeats: Bool, isRequired: Bool) -> CommandSlot {
        let name = word.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let isPairs = repeats && (name == "input" || name.contains("="))
        return CommandSlot(name: isPairs ? "input" : name, kind: isPairs ? .pairs : repeats ? .words : .word, isRequired: isRequired, option: nil)
    }
}
