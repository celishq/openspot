import Foundation

enum CheckCall: NounCall {
    case folder(String?, form: PrintForm)
    case sheet

    static let noun = CommandNoun("check", group: .build, verbs: [
        CommandVerb("spots", "[--json] [folder]", "Loads each spot of a spots folder, runs it once, and reports each fault.", rule: CallRule(flags: .startsScripts)) { words in
            let json = words.rest.first == PrintForm.jsonWord
            let rest = json ? Array(words.rest.dropFirst()) : words.rest
            return rest.count <= 1 ? Self.folder(rest.first, form: json ? .json : .frame) : nil
        },
        CommandVerb("sheet", "", "Reports the faults of a sheet on stdin.") { $0.none ? Self.sheet : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = CheckCalls(input: context.input, environment: context.environment, place: context.folder, tokens: context.runs?.tokens)
        return switch self {
        case .folder(let path, let form): calls.folder(path, form: form, careful: context.careful)
        case .sheet: calls.sheet()
        }
    }
}
