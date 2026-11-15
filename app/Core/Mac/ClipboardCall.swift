import Foundation

public enum ClipboardCall: NounCall {
    case copy(String?)
    case paste
    case read

    static let noun = CommandNoun("clipboard", verbs: [
        CommandVerb("copy", "[file]", "Copies the file as Finder does, or the text on stdin.", rule: CallRule(use: .clipboard, used: "copied to the clipboard", read: .changes("changes the clipboard"))) { words in
            words.rest.count <= 1 ? Self.copy(words.rest.first) : nil
        },
        CommandVerb("paste", "", "Pastes the clipboard into the front app.", rule: CallRule(use: .clipboard, used: "pasted the clipboard", read: .changes("types in the front app"))) { $0.none ? Self.paste : nil },
        CommandVerb("read", "", "Prints the text on the clipboard, or nothing when it holds none.", rule: CallRule(use: .clipboard, used: "read the clipboard")) { $0.none ? Self.read : nil }
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
        case .read: calls.read()
        }
    }
}
