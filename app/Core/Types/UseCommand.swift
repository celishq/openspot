import Foundation

struct UseCommand: Sendable {
    let noun: String
    let method: String
    let words: [String]
    let slots: [CommandSlot]

    static func all(for uses: Set<SpotUse>) -> [UseCommand] {
        CommandNoun.all.flatMap { noun in
            noun.shown.filter { $0.rule.use.map(uses.contains) == true }.map { verb in
                UseCommand(noun: noun.name, method: CommandSlot.identifier(verb.words), words: [noun.name] + verb.words, slots: CommandSlot.slots(of: verb.form))
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
