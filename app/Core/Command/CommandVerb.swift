import Foundation

public struct CommandVerb: Sendable {
    public let words: [String]
    public let form: String
    public let about: String
    public let rule: CallRule
    let shape: CommandForm
    let parse: @Sendable (CallWords) -> (any NounCall)?

    init(_ words: String = "", _ form: String = "", _ about: String = "", rule: CallRule = CallRule(), parse: @escaping @Sendable (CallWords) -> (any NounCall)?) {
        self.words = words.split(separator: " ").map(String.init)
        self.form = form
        self.about = about
        self.rule = rule
        shape = CommandForm(form)
        self.parse = parse
    }

    public var inputs: [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        let groups = try? NSRegularExpression(pattern: #"\[((?:[^\[\]]|\[[^\]]*\])*)\](\.\.\.)?|(\S+)"#)
        for match in groups?.matches(in: form, range: NSRange(form.startIndex..., in: form)) ?? [] {
            let text = { (index: Int) in Range(match.range(at: index), in: form).map { String(form[$0]) } }
            if let word = text(3) {
                let repeats = word.hasSuffix("...")
                let name = Self.name(word)
                properties[name] = repeats ? ["type": "array", "items": ["type": "string"]] : ["type": "string"]
                required.append(name)
                continue
            }
            let repeats = text(2) != nil
            for choice in (text(1) ?? "").split(separator: "|").map({ $0.split(separator: " ").map(String.init) }) {
                guard let first = choice.first else { continue }
                let isOption = first.hasPrefix("--")
                let name = isOption ? String(first.dropFirst(2)) : Self.name(choice.joined(separator: "-"))
                let single: [String: Any] = ["type": isOption && choice.count == 1 ? "boolean" : "string"]
                properties[name] = repeats ? ["type": "array", "items": single] : single
            }
        }
        return ["type": "object", "properties": properties, "required": required]
    }

    private static func name(_ word: String) -> String {
        word.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
    }

    func matches(_ rest: [String]) -> Bool {
        rest.count >= words.count && Array(rest.prefix(words.count)) == words
    }
}
