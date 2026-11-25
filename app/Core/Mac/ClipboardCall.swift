import Foundation

public enum ClipboardCall: NounCall {
    case copy(String?)
    case paste(opening: Bool, sending: Bool)
    case read

    static let noun = CommandNoun("clipboard", group: .mac, verbs: [
        CommandVerb("copy", "[file]", "Copies the file as Finder does, or the text on stdin.", rule: CallRule(use: .clipboard, used: "copied to the clipboard", inShow: .changes("changes the clipboard"))) { words in
            words.rest.count <= 1 ? Self.copy(words.rest.first) : nil
        },
        CommandVerb("paste", "[--new] [--send]", "Pastes the clipboard into the front app. --new first presses `⌘N` for a new chat or document, and --send presses Return after it.", rule: CallRule(use: .clipboard, used: "pasted the clipboard", inShow: .changes("types in the front app"))) { words in
            words.fit.flatMap { $0.rest.isEmpty ? Self.paste(opening: $0.has("--new"), sending: $0.has("--send")) : nil }
        },
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
        case .paste(let opening, let sending): calls.paste(opening: opening, sending: sending)
        case .read: calls.read()
        }
    }
}
