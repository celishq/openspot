import Foundation

enum TranslateCall: NounCall {
    case text(from: String?, to: String?)
    case languages

    static let noun = CommandNoun("translate", verbs: [
        CommandVerb("", "[--from code] [--to code]", "Translates the text on stdin.", rule: CallRule(flags: .readsInput)) { words in
            let rest = words.rest
            guard rest.count.isMultiple(of: 2) else { return nil }
            var options: [String: String] = [:]
            for index in stride(from: 0, to: rest.count, by: 2) {
                guard rest[index] == "--from" || rest[index] == "--to" else { return nil }
                options[rest[index]] = rest[index + 1]
            }
            return Self.text(from: options["--from"].flatMap { $0 == "auto" ? nil : $0 }, to: options["--to"])
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
