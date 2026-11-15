import Foundation

enum CheckCall: NounCall {
    case folder(String?, json: Bool)
    case sheet

    static let noun = CommandNoun("check", verbs: [
        CommandVerb("", "[--json] [folder]", "Reports the faults of a spots folder.", rule: CallRule(flags: .startsScripts)) { words in
            let json = words.rest.first == "--json"
            let rest = json ? Array(words.rest.dropFirst()) : words.rest
            return rest.count <= 1 ? Self.folder(rest.first, json: json) : nil
        },
        CommandVerb("--sheet", "", "Reports the faults of a sheet on stdin.") { $0.none ? Self.sheet : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = CheckCalls(input: context.input, environment: context.environment, place: context.folder, tokens: context.runs?.tokens)
        return switch self {
        case .folder(let path, let json): calls.folder(path, json: json, careful: context.careful)
        case .sheet: calls.sheet()
        }
    }
}
