import Foundation

enum HelpCall: NounCall {
    case list
    case guide(String)

    static let flag = "--help"

    static let noun = CommandNoun("help", verbs: [
        CommandVerb("", "[noun]", "Prints this list, or the guide of a noun: \(CommandNoun.guides).") { words in
            words.none ? Self.list : words.one.map(Self.guide)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .list:
            return { [usage = context.usage] in CommandAnswer(output: usage) }
        case .guide(let noun):
            return CommandAnswer.work { [nouns = context.nouns] in
                guard let folder = Bundle.main.url(forResource: "Help", withExtension: nil) else { throw SpotError.fault("This copy of Openspot has no guides. Install Openspot again.") }
                return try CommandGuide(folder: folder, nouns: nouns).text(of: noun)
            }
        }
    }
}
