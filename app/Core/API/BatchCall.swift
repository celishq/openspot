import Foundation

enum BatchCall: NounCall {
    case run

    static let noun = CommandNoun("batch", verbs: [
        CommandVerb("", "", "Runs one call for each line of stdin, its words split at spaces, and prints the output of each with a line --- after it. It stops at the first call that fails, and takes only a call that the app answers.", rule: CallRule(flags: .readsInput)) { $0.none ? Self.run : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        BatchCalls(api: context.api, request: context.request).run(context.input, output: context.output)
    }
}
