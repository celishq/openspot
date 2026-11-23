import Foundation

enum PromptCall: NounCall {
    case new(String)
    case change(id: String, words: String, failure: String?)
    case theme(String, words: String)

    static let noun = CommandNoun("prompt", group: .build, verbs: [
        CommandVerb("new", "[words]...", "Prints a prompt that asks a coding agent to build a spot that does what the words say. With no words, the agent asks you first.") { words in
            Self.new(words.rest.joined(separator: " "))
        },
        CommandVerb("change", "<id> [--failure <text>] [words]...", "Prints a prompt that asks a coding agent to change the spot as the words say, with what the stats counted of it over 14 days. With no words, its goal follows those counts, or the agent asks you what to change when there are none.") { words in
            guard let fit = words.fit, let id = fit.rest.first else { return nil }
            return Self.change(id: id, words: fit.rest.dropFirst().joined(separator: " "), failure: fit.value("--failure"))
        },
        CommandVerb("theme", "<name> [words]...", "Prints a prompt that asks a coding agent to change a theme as the words say. With no words, the agent asks you first.") { words in
            words.rest.first.map { Self.theme($0, words: words.rest.dropFirst().joined(separator: " ")) }
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = PromptCalls(mac: context.mac, places: context.places, runs: context.runs)
        return switch self {
        case .new(let words): calls.new(words)
        case .change(let id, let words, let failure): calls.change(id, words: words, failure: failure)
        case .theme(let name, let words): calls.theme(name, words: words)
        }
    }
}
