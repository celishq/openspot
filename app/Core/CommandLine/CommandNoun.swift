import Foundation

public struct CommandNoun: Sendable {
    public let name: String
    public let guide: String?
    public let verbs: [CommandVerb]
    let loose: (@Sendable (_ verb: CommandVerb, _ rest: [String], _ spot: String) -> CallRule?)?

    init(_ name: String, guide: String? = nil, verbs: [CommandVerb], loose: (@Sendable (_ verb: CommandVerb, _ rest: [String], _ spot: String) -> CallRule?)? = nil) {
        self.name = name
        self.guide = guide
        self.verbs = verbs
        self.loose = loose
    }

    public static let all: [CommandNoun] = [
        GuideCall.noun, HelpCall.noun, SpotCall.noun, GridCall.noun, StoreCall.noun, CheckCall.noun, RenderCall.noun,
        PlaygroundCommand.noun, ColorCall.noun, FolderCall.noun, SettingCall.noun, PromptCall.noun, AppCall.noun, ThemeCall.noun, BatchCall.noun,
        UpdateCall.noun, AccountCall.noun, ClipboardCall.noun, EventCall.noun, TranslateCall.noun, CalcCall.noun, EmojiCall.noun,
        SymbolsCall.noun, WindowCall.noun, ScreenCall.noun, CalendarCall.noun, RemindersCall.noun, HelperCall.noun
    ]

    func verb(of rest: [String]) -> CommandVerb? {
        verbs.filter { $0.matches(rest) }.max { $0.words.count < $1.words.count }
    }

    static let guides = "<guides>"

    static func listed(_ words: [String]) -> String {
        words.count < 2 ? words.joined() : words.dropLast().joined(separator: ", ") + " or " + (words.last ?? "")
    }

    func lines(guides: String) -> [String] {
        verbs.filter { !$0.about.isEmpty }.map { verb in
            let form = (["openspot", name] + verb.words + (verb.form.isEmpty ? [] : [verb.form])).joined(separator: " ")
            let about = Self.wrapped(verb.about.replacingOccurrences(of: Self.guides, with: guides))
            let first = form.count < Self.column ? form.padding(toLength: Self.column, withPad: " ", startingAt: 0) + about[0] : form + "\n" + Self.indent + about[0]
            return ([first] + about.dropFirst().map { Self.indent + $0 }).joined(separator: "\n")
        }
    }

    private static let column = 45
    private static let width = 75
    private static let indent = String(repeating: " ", count: column)

    private static func wrapped(_ text: String) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ") {
            if !line.isEmpty, line.count + 1 + word.count > width {
                lines.append(line)
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        return lines + [line]
    }
}
