import Foundation

enum EmojiCall: NounCall {
    case rows(tone: EmojiCatalog.Tone)

    static let noun = CommandNoun("emoji", group: .mac, verbs: [
        CommandVerb("list", "[--tone name]", "Prints each emoji as a row, with its name in the language of the Mac. A tone is none, light, medium-light, medium, medium-dark or dark.", rule: CallRule(flags: .pure)) { words in
            guard let fit = words.fit, fit.rest.isEmpty, let tone = fit.value("--tone").map({ EmojiCatalog.Tone(rawValue: $0) }) ?? EmojiCatalog.Tone.none else { return nil }
            return Self.rows(tone: tone)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .rows(let tone) = self else { return nil }
        return CommandAnswer.work { try EmojiCatalog().rows(tone: tone) }
    }
}
