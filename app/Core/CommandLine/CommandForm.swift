import Foundation

public struct CommandForm: Sendable {
    public struct Words: Equatable, Sendable {
        public let rest: [String]
        let options: [String: [String]]

        func has(_ name: String) -> Bool {
            options[name] != nil
        }

        func value(_ name: String) -> String? {
            options[name]?.first
        }

        func values(_ name: String) -> [String] {
            options[name] ?? []
        }

        var days: Int? {
            value("--days").map { Int($0).flatMap { $0 > 0 ? $0 : nil } } ?? 1
        }

        var form: PrintForm {
            has(PrintForm.jsonWord) ? .json : .frame
        }
    }

    private struct Option {
        let takesValue: Bool
        let repeats: Bool
    }

    private let options: [String: Option]
    private let isOpen: Bool

    init(_ form: String) {
        var options: [String: Option] = [:]
        var isOpen = false
        let groups = try? NSRegularExpression(pattern: #"\[((?:[^\[\]]|\[[^\]]*\])*)\](\.\.\.)?|(\S+)"#)
        for match in groups?.matches(in: form, range: NSRange(form.startIndex..., in: form)) ?? [] {
            let text = { (index: Int) in Range(match.range(at: index), in: form).map { String(form[$0]) } }
            guard let inside = text(1) else {
                if text(3)?.hasSuffix("...") == true { isOpen = true }
                continue
            }
            let repeats = text(2) != nil
            var named = false
            for choice in inside.split(separator: "|").map({ $0.split(separator: " ").map(String.init) }) {
                guard let name = choice.first, name.hasPrefix("--") else { continue }
                options[name] = Option(takesValue: choice.count > 1, repeats: repeats)
                named = true
            }
            if repeats, !named { isOpen = true }
        }
        self.options = options
        self.isOpen = isOpen
    }

    func fit(_ words: [String]) -> Words? {
        var found: [String: [String]] = [:]
        var rest: [String] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            index += 1
            guard let option = options[word] else {
                guard isOpen || !word.hasPrefix("--") else { return nil }
                rest.append(word)
                continue
            }
            guard option.repeats || found[word] == nil else { return nil }
            if option.takesValue {
                guard index < words.count else { return nil }
                found[word, default: []].append(words[index])
                index += 1
            } else {
                found[word] = []
            }
        }
        return Words(rest: rest, options: found)
    }
}
