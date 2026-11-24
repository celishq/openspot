import Foundation

public struct CommandNoun: Sendable {
    public let name: String
    public let group: CommandGroup
    public let guide: String?
    public let flags: [String]
    public let verbs: [CommandVerb]
    let loose: (@Sendable (_ verb: CommandVerb, _ rest: [String], _ spot: String) -> CallRule?)?

    init(_ name: String, group: CommandGroup, guide: String? = nil, flags: [String] = [], verbs: [CommandVerb], loose: (@Sendable (_ verb: CommandVerb, _ rest: [String], _ spot: String) -> CallRule?)? = nil) {
        self.name = name
        self.group = group
        self.guide = guide
        self.flags = flags
        self.verbs = verbs
        self.loose = loose
    }

    public static let all: [CommandNoun] = [
        GuideCall.noun, HelpCall.noun, SpotCall.noun, ToastCall.noun, SelectCall.noun, RouteCall.noun, GridCall.noun, StoreCall.noun, CheckCall.noun, RenderCall.noun,
        PlaygroundCommand.noun, ColorCall.noun, FolderCall.noun, SettingCall.noun, PromptCall.noun, AppCall.noun, ThemeCall.noun, BatchCall.noun,
        UpdateCall.noun, VersionCall.noun, AccountCall.noun, ClipboardCall.noun, TranslateCall.noun, DateCall.noun, EmojiCall.noun,
        SymbolsCall.noun, WindowCall.noun, ScreenCall.noun, CalendarCall.noun, RemindersCall.noun, PowerCall.noun, HelperCall.noun, TimerCall.noun, SchemaCall.noun, RunCall.noun, EmitCall.noun, TypesCall.noun, CacheCall.noun
    ]

    func verb(of rest: [String]) -> CommandVerb? {
        verbs.filter { $0.matches(rest) }.max { $0.words.count < $1.words.count }
    }

    var shown: [CommandVerb] {
        verbs.filter { !$0.about.isEmpty }
    }

    func lines(verb words: [String] = []) -> [String] {
        shown.filter { Array($0.words.prefix(words.count)) == words }.map { verb in
            let form = (["openspot", name] + verb.words + (verb.form.isEmpty ? [] : [verb.form])).joined(separator: " ")
            let about = Self.wrapped(verb.about)
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
