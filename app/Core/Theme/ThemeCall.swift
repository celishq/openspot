import Foundation

enum ThemeCall: NounCall {
    case reload
    case open

    static let noun = CommandNoun("theme", group: .app, verbs: [
        CommandVerb("reload", "", "Reads the theme of the app again from its file, and draws with it.", rule: CallRule(use: .app, used: "reloaded the theme", read: .changes("redraws Openspot"))) { $0.none ? Self.reload : nil },
        CommandVerb("open", "", "Opens your copy of the theme in the text editor, and makes it from the theme of the app the first time.", rule: CallRule(use: .app, used: "opened the theme", read: .changes("opens a window"))) { $0.none ? Self.open : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let file = ThemeFile.standard(environment: context.environment, builtIn: context.mac.theme)
        return switch self {
        case .reload:
            CommandAnswer.work { [app = context.app] in
                let theme = file.read()
                guard theme.faults.isEmpty else { throw SpotError.failed(1, theme.faults.joined(separator: "\n")) }
                await app?.apply(theme)
                return ""
            }
        case .open:
            CommandAnswer.work { [openText = context.mac.openText] in
                let copy = try file.makeCopy()
                guard let openText else { throw SpotError.fault("This Mac has no text editor.") }
                await openText(copy)
                return ""
            }
        }
    }
}
