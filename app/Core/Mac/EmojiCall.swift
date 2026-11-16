import Foundation

enum EmojiCall: NounCall {
    case rows(tone: EmojiCatalog.Tone)

    static let noun = CommandNoun("emoji", group: .mac, verbs: [
        CommandVerb("", "[--tone name]", "Prints each emoji as a row, with its name in the language of the Mac. A tone is none, light, medium-light, medium, medium-dark or dark.", rule: CallRule(flags: .pure)) { words in
            if words.none { return Self.rows(tone: .none) }
            guard words.rest.count == 2, words.rest[0] == "--tone", let tone = EmojiCatalog.Tone(rawValue: words.rest[1]) else { return nil }
            return Self.rows(tone: tone)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .rows(let tone) = self else { return nil }
        return CommandAnswer.work { try EmojiCatalog().rows(tone: tone) }
    }
}
