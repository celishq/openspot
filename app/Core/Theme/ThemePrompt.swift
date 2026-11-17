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

    static let finishAlone = "Don't ask me anything. Make the change to the end, and leave Openspot drawn with the theme."

    public func asking(_ wish: String) -> String {
        let opening = wish.isEmpty
            ? "Change the look of Openspot, its theme \(theme). Ask me what look I want before you change it."
            : "Change the look of Openspot, its theme \(theme): \(wish)\n\(Self.finishAlone)"
        return """
        \(opening)

        \(file)
        A key that the file leaves out keeps its value from the theme \(ThemeFolder.builtInName)\(base.map { ", in \($0.path)" } ?? "").
        Run "\(app)" guide, and read its section Change the look of Openspot, which says what each section holds.
        The file holds these sections and keys:
        \(keys)
        Every other value of the look follows from these keys. Set one exactly only when the rule gives the wrong value; the guide lists those keys.
        After each change, run "\(app)" theme reload. It draws Openspot with the file and prints each value it can't read. Fix each one until it prints nothing.

        """
    }

    private var file: String {
        guard isBuiltIn else {
            return "Run \"\(app)\" theme use \(quotedTheme). Then change the file \(folder.appendingPathComponent("\(theme).theme/theme.toml").path)."
        }
        return "The theme \(theme) comes with Openspot, so it can't change. First run \"\(app)\" theme duplicate \(quotedTheme). It makes a copy you can change, uses it, and prints its name, such as \(theme) copy. Then change the file theme.toml in the folder \(folder.path)/<name of the copy>.theme."
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
