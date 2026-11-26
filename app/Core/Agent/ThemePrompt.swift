import Foundation

public struct ThemePrompt: Equatable, Sendable {
    public let theme: String
    public let folder: URL
    public let isBuiltIn: Bool
    public let base: URL?
    public let app: String

    public init(theme: String, folder: URL, isBuiltIn: Bool, base: URL?, app: String) {
        self.theme = theme
        self.folder = folder
        self.isBuiltIn = isBuiltIn
        self.base = base
        self.app = app
    }

    static let finish = "Make the change to the end, and leave Openspot drawn with the theme."
    static let wordsNeeded = "Say what look you want, such as `openspot prompt theme Openspot warm colours and round corners`."

    public func asking(_ wish: String) -> String {
        AgentPrompt(
            app: app,
            task: "Change the look of Openspot, its theme \(theme), as my request says.",
            place: [
                file,
                "A key that the file leaves out keeps its value from the theme \(ThemeFolder.builtInName)\(base.map { ", in \($0.path)" } ?? "")."
            ],
            reading: [
                "Run \(quoted) guide use-openspot, and read its section Change the look of Openspot. It says what each key does, and which values to set only when the rule gives the wrong one.",
                "The file holds these sections and keys, and every other value of the look follows from them:\n\(keys)"
            ],
            finish: Self.finish,
            rules: [
                "After each change, run \(quoted) theme reload. It draws Openspot with the file and prints each value it can't read. It's done when it prints nothing."
            ],
            request: wish
        ).text
    }

    private var quoted: String {
        AgentPrompt.quoted(app)
    }

    private var file: String {
        guard isBuiltIn else {
            return "Run \(quoted) theme use \(quotedTheme). Then change the file \(folder.appendingPathComponent("\(theme).theme/theme.toml").path)."
        }
        return "The theme \(theme) comes with Openspot, so it can't change. First run \(quoted) theme duplicate \(quotedTheme). It makes a copy you can change, uses it, and prints its name, such as \(theme) copy. Then change the file theme.toml in the folder \(folder.path)/<name of the copy>.theme."
    }

    private var quotedTheme: String {
        "'" + theme.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private var keys: String {
        let sections = Theme.keys.reduce(into: [(section: String, keys: [String])]()) { sections, key in
            if sections.last?.section == key.section { sections[sections.count - 1].keys.append(key.key) } else { sections.append((key.section, [key.key])) }
        }
        return sections.map { "[\($0.section)] \($0.keys.joined(separator: ", "))" }.joined(separator: "\n")
    }
}
