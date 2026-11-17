import Foundation

enum ThemeCall: NounCall, Equatable {
    case list(PrintForm)
    case use(String)
    case new
    case duplicate(String?)
    case rename(String, String)
    case delete(String)
    case open
    case reload

    private static let changes = CallRule.Read.changes("changes the theme")

    static let noun = CommandNoun("theme", verbs: [
        CommandVerb("list", "[--frame]", "Prints each theme, with the built-in one and the one in use marked.") { $0.form.map(Self.list) },
        CommandVerb("use", "<name>", "Draws Openspot with a theme.", rule: CallRule(use: .app, used: "switched the theme", read: changes)) { $0.one.map(Self.use) },
        CommandVerb("new", "", "Makes a theme with the values of the built-in one, and uses it.", rule: CallRule(use: .app, used: "made a theme", read: changes)) { $0.none ? Self.new : nil },
        CommandVerb("duplicate", "[name]", "Copies the theme in use, or the named one, and uses the copy.", rule: CallRule(use: .app, used: "made a theme", read: changes)) { words in
            words.rest.count < 2 ? Self.duplicate(words.rest.first) : nil
        },
        CommandVerb("rename", "<name> <new name>", "Renames a theme.", rule: CallRule(use: .app, used: "renamed a theme", read: changes)) { words in
            words.rest.count == 2 ? Self.rename(words.rest[0], words.rest[1]) : nil
        },
        CommandVerb("delete", "<name>", "Moves a theme to the Trash. Deleting the one in use switches to the built-in one.", rule: CallRule(use: .app, used: "deleted a theme", read: changes)) { $0.one.map(Self.delete) },
        CommandVerb("open", "", "Opens the file of the theme in use in the text editor. The built-in theme can't change, so it opens a copy, which it uses.", rule: CallRule(use: .app, used: "opened the theme", read: .changes("opens a window"))) { $0.none ? Self.open : nil },
        CommandVerb("reload", "", "Reads the theme in use again from its file, and draws with it.", rule: CallRule(use: .app, used: "reloaded the theme", read: .changes("redraws Openspot"))) { $0.none ? Self.reload : nil }
    ])

    private struct PrintedTheme: PrintedRecord {
        let theme: String
        let builtin, used: Bool

        var blocks: [[(String, String?)]] {
            [[("theme", theme), ("builtin", builtin ? "true" : nil), ("used", used ? "true" : nil)]]
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let themes = ThemeFolder.standard(environment: context.environment, builtIn: context.mac.theme)
        let app = context.app
        let draw = { @Sendable (line: String) async throws -> String in
            let theme = themes.read()
            guard theme.faults.isEmpty else { throw SpotError.failed(1, ([line] + theme.faults).filter { !$0.isEmpty }.joined(separator: "\n")) }
            await app?.apply(theme)
            return line.isEmpty ? "" : line + "\n"
        }
        return switch self {
        case .list(let form):
            CommandAnswer.work {
                let used = themes.readInUse()
                return try form.text(of: themes.scan().map { PrintedTheme(theme: $0, builtin: ThemeFolder.isBuiltIn($0), used: $0 == used) })
            }
        case .use(let name):
            CommandAnswer.work { try await draw("Switched to the theme \(try themes.use(name)).") }
        case .new:
            CommandAnswer.work { try await draw("Made the theme \(try themes.make()), and switched to it.") }
        case .duplicate(let name):
            CommandAnswer.work { try await draw("Made the theme \(try themes.duplicate(name)), and switched to it.") }
        case .rename(let old, let new):
            CommandAnswer.work { "Renamed the theme \(old) to \(try themes.rename(old, to: new)).\n" }
        case .delete(let name):
            CommandAnswer.work { [trash = context.trash] in
                let found = themes.scan().first { $0.caseInsensitiveCompare(name) == .orderedSame } ?? name
                guard try themes.delete(name, trash: trash) else { return "Moved the theme \(found) to the Trash.\n" }
                return try await draw("Moved the theme \(found) to the Trash, and switched to the theme \(ThemeFolder.builtInName).")
            }
        case .reload:
            CommandAnswer.work { try await draw("") }
        case .open:
            CommandAnswer.work { [openText = context.mac.openText] in
                guard let openText else { throw SpotError.fault("This Mac has no text editor.") }
                let isBuiltIn = ThemeFolder.isBuiltIn(themes.readInUse())
                let file = try themes.edit()
                if isBuiltIn { _ = try await draw("") }
                await openText(file)
                return ""
            }
        }
    }
}
