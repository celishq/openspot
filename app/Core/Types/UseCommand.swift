import Foundation

struct UseCommand: Sendable {
    let noun: String
    let method: String
    let words: [String]
    let slots: [CommandSlot]

    private static let envNouns: Set<String> = [RunCall.noun.name, EmitCall.noun.name]

    static func all(for uses: Set<SpotUse>) -> [UseCommand] {
        CommandNoun.all.filter { !envNouns.contains($0.name) }.flatMap { noun in
            noun.shown.filter { $0.rule.onlyPerson == nil && $0.rule.use.map(uses.contains) != false }.map { verb in
                UseCommand(
                    noun: noun.name, method: verb.words.isEmpty ? "" : CommandSlot.identifier(verb.words), words: [noun.name] + verb.words,
                    slots: CommandSlot.slots(of: verb.form)
                )
            }
        }
    }

    static func spec(for uses: Set<SpotUse>) -> [String: [String: Any]] {
        var spec: [String: [String: Any]] = [:]
        for command in all(for: uses) {
            spec[command.noun, default: [:]][command.method] = ["words": command.words, "slots": command.slots.map(\.spec)]
        }
        return spec
    }
}
