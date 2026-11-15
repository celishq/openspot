import Foundation

public enum HelperCall: NounCall {
    case capability(String)
    case glyphs(side: Double, fontSize: Double, path: String)

    static let noun = CommandNoun("helper", verbs: [
        CommandVerb("", rule: CallRule(flags: .ownProcess)) { words in words.one.map(Self.capability) },
        CommandVerb("glyphs", rule: CallRule(flags: .ownProcess)) { words in
            guard words.rest.count == 3, let side = Double(words.rest[0]), let fontSize = Double(words.rest[1]) else { return nil }
            return Self.glyphs(side: side, fontSize: fontSize, path: words.rest[2])
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        nil
    }
}
