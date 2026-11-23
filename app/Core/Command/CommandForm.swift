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
    private let fixed: Int

    init(_ form: String) {
        self.init(CommandSlot.slots(of: form))
    }

    init(_ slots: [CommandSlot]) {
        var options: [String: Option] = [:]
        for slot in slots {
            if let option = slot.option { options[option] = Option(takesValue: slot.kind == .option, repeats: slot.isRepeated) }
        }
        self.options = options
        isOpen = slots.contains { $0.isPositional && $0.isRepeated }
        fixed = slots.prefix { !$0.isPositional || !$0.isRepeated }.filter(\.isPositional).count
    }

    func fit(_ words: [String]) -> Words? {
        var found: [String: [String]] = [:]
        var rest: [String] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            index += 1
            guard let option = options[word], !isOpen || rest.count <= fixed else {
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
