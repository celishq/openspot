import Foundation

enum TranslateCall: NounCall {
    case text(from: String?, to: String?)
    case languages

    static let noun = CommandNoun("translate", group: .mac, verbs: [
        CommandVerb("text", "[--from code] [--to code]", "Translates the text on stdin.", rule: CallRule(flags: .readsInput)) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            return Self.text(from: fit.value("--from").flatMap { $0 == "auto" ? nil : $0 }, to: fit.value("--to"))
        },
        CommandVerb("languages", "", "Prints the languages it knows.") { $0.none ? Self.languages : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .text(let from, let to): CommandAnswer.work { [mac = context.mac.translation, input = context.input] in
            guard let mac else { throw SpotError.fault("This Mac cannot translate.") }
            return try await mac.translate(await input(), from: from, to: to).block.text
        }
        case .languages: CommandAnswer.work { [mac = context.mac.translation] in
            guard let mac else { return "" }
            return TranslatedText.languages(try await mac.languages())
        }
        }
    }
}
