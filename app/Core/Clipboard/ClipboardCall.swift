import Foundation

public enum ClipboardCall: NounCall {
    case copy(String?)
    case paste
    case read(within: TimeInterval?, blocks: Bool = false)

    static let noun = CommandNoun("clipboard", group: .mac, verbs: [
        CommandVerb("copy", "[file]", "Copies the file as Finder does, or the text on stdin.", rule: CallRule(use: .clipboard, used: "copied to the clipboard", inShow: .changes("changes the clipboard"))) { words in
            words.rest.count <= 1 ? Self.copy(words.rest.first) : nil
        },
        CommandVerb("paste", "", "Pastes the clipboard into the front app.", rule: CallRule(use: .clipboard, used: "pasted the clipboard", inShow: .changes("types in the front app"), needs: [.accessibility])) { $0.none ? Self.paste : nil },
        CommandVerb(
            "read", "[--within age] [--blocks]", "Prints the text on the clipboard, or nothing when it holds none. --within prints it only when Openspot first saw that copy within the age, such as 2m: seconds, or a number with s, m, h or d. --blocks prints the copy in its kind, as `openspot timeline add` takes it: `text=`, `url=`, or `file=` once for each file, with an image saved to a file, and nothing for a password, a one-time code or a text over 25 MB.",
            rule: CallRule(use: .clipboard, used: "read the clipboard")
        ) { words in
            let isBlocks = words.fit?.has("--blocks") == true
            return Self.within(in: words.fit).map { Self.read(within: $0, blocks: isBlocks) }
        }
    ])

    static let withinForm = CommandForm("[--within age]")

    static func within(in fit: CommandForm.Words?) -> TimeInterval?? {
        guard let fit, fit.rest.isEmpty else { return nil }
        guard let within = fit.value("--within") else { return .some(nil) }
        let age = Manifest.Triggers.age(orSeconds: within)
        return age.flatMap { $0 > 0 ? .some($0) : nil }
    }

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
        case .read(nil, false): calls.read()
        case .read(let within?, false): context.runs.map { calls.read(within: within, runs: $0) } ?? CommandAnswer.notRunning("clipboard read --within")
        case .read(nil, true): calls.blocks(images: context.places.clipboard, clock: context.runs?.clock ?? RunClock())
        case .read(let within?, true): context.runs.map { calls.blocks(images: context.places.clipboard, clock: $0.clock, within: within, runs: $0) } ?? CommandAnswer.notRunning("clipboard read --within")
        }
    }
}
