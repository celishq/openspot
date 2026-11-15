import Foundation

enum PromptCall: NounCall {
    case new(String)
    case change(id: String, words: String, failure: String?)

    static let noun = CommandNoun("prompt", verbs: [
        CommandVerb("new", "[words]...", "Prints a prompt that asks a coding agent to build a spot that does what the words say. With no words, the agent asks you first.") { words in
            Self.new(words.rest.joined(separator: " "))
        },
        CommandVerb("change", "<id> [--failure <text>] [words]...", "Prints a prompt that asks a coding agent to change the spot as the words say. With no words, the agent asks you what to change.") { words in
            guard let id = words.rest.first else { return nil }
            let rest = Array(words.rest.dropFirst())
            let failure = rest.first == "--failure" && rest.count > 1 ? rest[1] : nil
            return Self.change(id: id, words: (failure == nil ? rest : Array(rest.dropFirst(2))).joined(separator: " "), failure: failure)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = PromptCalls(mac: context.mac, environment: context.environment)
        return switch self {
        case .new(let words): calls.new(words)
        case .change(let id, let words, let failure): calls.change(id, words: words, failure: failure)
        }
    }
}
