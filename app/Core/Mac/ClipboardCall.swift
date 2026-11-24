import Foundation

public enum ClipboardCall: NounCall {
    case copy(String?)
    case paste
    case read(newer: TimeInterval?)

    static let noun = CommandNoun("clipboard", group: .mac, verbs: [
        CommandVerb("copy", "[file]", "Copies the file as Finder does, or the text on stdin.", rule: CallRule(use: .clipboard, used: "copied to the clipboard", inShow: .changes("changes the clipboard"))) { words in
            words.rest.count <= 1 ? Self.copy(words.rest.first) : nil
        },
        CommandVerb("paste", "", "Pastes the clipboard into the front app.", rule: CallRule(use: .clipboard, used: "pasted the clipboard", inShow: .changes("types in the front app"))) { $0.none ? Self.paste : nil },
        CommandVerb(
            "read", "[--newer age]", "Prints the text on the clipboard, or nothing when it holds none. --newer prints it only when Openspot first saw that copy within the age, such as 2m: seconds, or a number with s, m, h or d.",
            rule: CallRule(use: .clipboard, used: "read the clipboard")
        ) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            guard let newer = fit.value("--newer") else { return Self.read(newer: nil) }
            let age = Int(newer).map(TimeInterval.init) ?? Manifest.Triggers.age(newer)
            return age.flatMap { $0 > 0 ? Self.read(newer: $0) : nil }
        }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard case .copy(nil) = self else { return rule }
        var rule = rule
        rule.flags.insert(.readsInput)
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = ClipboardCalls(mac: context.mac.clipboard, folder: context.folder)
        return switch self {
        case .copy(let path): calls.copy(path, input: context.input)
        case .paste: calls.paste()
        case .read(nil): calls.read()
        case .read(let newer?): context.runs.map { calls.read(newer: newer, runs: $0) } ?? CommandAnswer.notRunning("clipboard read --newer")
        }
    }
}
