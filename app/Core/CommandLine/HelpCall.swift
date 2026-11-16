import Foundation

enum HelpCall: NounCall {
    case list
    case json
    case verbs(String, verb: [String])

    static let jsonWord = "--json"
    private static let flags = ["--help", "-h"]

    static let noun = CommandNoun("help", group: .start, flags: flags, verbs: [
        CommandVerb("", "[noun [verb]] [--json]", "Prints this list, or the verbs of a noun and its page of the guide, when it has one. --help after any noun or verb does the same. --json prints each verb with its form, its effect and whether it needs the app.") { words in
            if words.rest.count == 1, Self.flags.contains(words.rest[0]) { return Self.list }
            guard let fit = words.fit else { return nil }
            if fit.has(Self.jsonWord) { return fit.rest.isEmpty ? Self.json : nil }
            guard let first = fit.rest.first, !first.hasPrefix("-") else { return fit.rest.isEmpty ? Self.list : nil }
            return Self.verbs(first, verb: Array(fit.rest.dropFirst()))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let help = CommandHelp(nouns: context.nouns)
        switch self {
        case .list:
            return { CommandAnswer(output: help.text) }
        case .json:
            return CommandAnswer.work { try PrintForm.json(help.entries) }
        case .verbs(let name, let verb):
            guard let noun = context.nouns.first(where: { $0.name == name }), case let text = help.verbs(of: noun, verb: verb), !text.isEmpty else {
                return { CommandAnswer(errors: help.unknown([name] + verb), code: 2) }
            }
            guard verb.isEmpty, noun.guide != nil else { return { CommandAnswer(output: text) } }
            return { [mac = context.mac, page = noun.guide ?? name] in
                CommandAnswer(output: text + (mac.readPages()[page].map { "\n" + $0 } ?? ""))
            }
        }
    }
}
