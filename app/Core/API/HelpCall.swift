import Foundation

enum HelpCall: NounCall {
    case list
    case json
    case noun(String, verb: [String])

    static let flags: Set<String> = ["--help", "-h"]
    static let jsonWord = "--json"

    static let noun = CommandNoun("help", group: .start, verbs: [
        CommandVerb("", "[noun [verb]] [--json]", "Prints this list, or the verbs of a noun and its guide, which \(CommandNoun.guides) have. --help after any noun or verb does the same. --json prints each verb with its form, its effect and whether it needs the app.") { words in
            if words.rest == [Self.jsonWord] { return Self.json }
            guard let first = words.rest.first, !first.hasPrefix("-") else { return words.none ? Self.list : nil }
            return Self.noun(first, verb: Array(words.rest.dropFirst()))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let help = CommandHelp(nouns: context.nouns)
        switch self {
        case .list:
            return { CommandAnswer(output: help.text) }
        case .json:
            return CommandAnswer.work { try PrintForm.json(help.entries) }
        case .noun(let name, let verb):
            guard let noun = context.nouns.first(where: { $0.name == name }), case let text = help.verbs(of: noun, verb: verb), !text.isEmpty else {
                return { CommandAnswer(errors: help.unknown(([name] + verb).joined(separator: " ")), code: 2) }
            }
            guard verb.isEmpty, noun.guide != nil else { return { CommandAnswer(output: text) } }
            return CommandAnswer.work { [nouns = context.nouns] in
                guard let folder = Bundle.main.url(forResource: "Help", withExtension: nil) else { throw SpotError.fault("This copy of Openspot has no guides. Install Openspot again.") }
                return text + "\n" + (try CommandGuide(folder: folder, nouns: nouns).text(of: name))
            }
        }
    }
}
