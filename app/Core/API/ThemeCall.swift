import Foundation

enum ThemeCall: NounCall {
    case reload

    static let noun = CommandNoun("theme", verbs: [
        CommandVerb("reload", "", "Reads the theme of the app again from its file, and draws with it.", rule: CallRule(use: .app, used: "reloaded the theme", read: .changes("redraws Openspot"))) { $0.none ? Self.reload : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        CommandAnswer.work { [mac = context.mac, app = context.app] in
            let theme = mac.theme.read()
            guard theme.faults.isEmpty else { throw SpotError.failed(1, theme.faults.joined(separator: "\n")) }
            await app?.apply(theme)
            return ""
        }
    }
}
