import Foundation

enum ThemeCall: NounCall, Equatable {
    case list(PrintForm)
    case use(String)
    case new
    case duplicate(String?)
    case rename(String, String)
    case delete(String)
    case open(String?)
    case reload

    private static let changes = CallRule.InShow.changes("changes the theme")

    static let noun = CommandNoun("theme", group: .app, verbs: [
        CommandVerb("list", "[--json]", "Prints each theme, with the built-in one and the one in use marked. --json prints them as JSON.") { $0.form.map(Self.list) },
        CommandVerb("use", "<name>", "Draws Openspot with a theme.", rule: CallRule(use: .app, used: "switched the theme", inShow: changes)) { $0.one.map(Self.use) },
        CommandVerb("new", "", "Makes a theme with the values of the built-in one, and uses it.", rule: CallRule(use: .app, used: "made a theme", inShow: changes)) { $0.none ? Self.new : nil },
        CommandVerb("duplicate", "[name]", "Copies the theme in use, or the named one, and uses the copy.", rule: CallRule(use: .app, used: "made a theme", inShow: changes)) { words in
            words.rest.count < 2 ? Self.duplicate(words.rest.first) : nil
        },
        CommandVerb("rename", "<name> <new name>", "Renames a theme.", rule: CallRule(use: .app, used: "renamed a theme", inShow: changes)) { words in
            words.rest.count == 2 ? Self.rename(words.rest[0], words.rest[1]) : nil
        },
        CommandVerb("delete", "<name>", "Moves a theme to the Trash. Deleting the one in use switches to the built-in one.", rule: CallRule(use: .app, used: "deleted a theme", inShow: changes)) { $0.one.map(Self.delete) },
        CommandVerb("open", "[name]", "Opens the file of the theme in use, or the named one, in the text editor. A built-in theme can't change, so it opens a copy, which it uses.", rule: CallRule(use: .app, used: "opened the theme", inShow: .changes("opens a window"))) { words in
            words.rest.count < 2 ? Self.open(words.rest.first) : nil
        },
        CommandVerb("reload", "", "Reads the theme in use again from its file, and draws with it.", rule: CallRule(use: .app, used: "reloaded the theme", inShow: .changes("redraws Openspot"))) { $0.none ? Self.reload : nil }
    ])

    private struct PrintedTheme: PrintedRecord {
        struct Swatch: Encodable {
            let background, ink, accent: String

            init(_ appearance: Theme.Appearance) {
                (background, ink, accent) = (appearance.background.text, appearance.ink.text, appearance.accent.text)
            }

            func fields(_ name: String) -> [(String, String?)] {
                [("\(name).background", background), ("\(name).ink", ink), ("\(name).accent", accent)]
            }
        }

        let theme: String
        let builtin, used: Bool
        let dark, light: Swatch

        var blocks: [[(String, String?)]] {
            [[("item", theme), ("builtin", builtin ? "true" : nil), ("used", used ? "true" : nil)] + dark.fields("dark") + light.fields("light")]
        }
    }

    struct Listed: Equatable, Sendable {
        let name: String
        let isBuiltIn: Bool
        let isUsed: Bool
        let colours: Theme.Colours
        let layout: Theme.Layout
    }

    static func listed(_ themes: ThemeFolder) -> [Listed] {
        let used = themes.readInUse()
        return themes.scan().items.map { item in
            let theme = ThemeFolder.read(builtIn: themes.builtIn, copy: item.file)
            return Listed(name: item.name, isBuiltIn: item.isBuiltIn, isUsed: item.name == used, colours: theme.colours, layout: theme.layout)
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let themes = ThemeFolder(config: context.places.config, builtIn: context.mac.theme)
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
                try form.text(of: Self.listed(themes).map { listed in
                    PrintedTheme(theme: listed.name, builtin: listed.isBuiltIn, used: listed.isUsed, dark: .init(listed.colours.dark), light: .init(listed.colours.light))
                })
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
                let found = themes.scan().find(name)?.name ?? name
                guard try themes.delete(name, trash: trash) else { return "Moved the theme \(found) to the Trash.\n" }
                return try await draw("Moved the theme \(found) to the Trash, and switched to the theme \(ThemeFolder.builtInName).")
            }
        case .reload:
            CommandAnswer.work { try await draw("") }
        case .open(let name):
            CommandAnswer.work { [openText = context.mac.openText] in
                guard let openText else { throw SpotError.fault("This Mac has no text editor.") }
                let edited = try themes.edit(name)
                if edited.isCopy { _ = try await draw("") }
                await openText(edited.file)
                return ""
            }
        }
    }
}
