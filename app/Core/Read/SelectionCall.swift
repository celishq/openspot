import Foundation

enum SelectionCall: NounCall {
    case read

    static let noun = CommandNoun("selection", group: .mac, verbs: [
        CommandVerb("read", "", "Prints the text= selected in the front app, and its app=.", rule: ReadSources.rule) { $0.none ? Self.read : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        ReadSources.work(in: context) { try await $0.selection(asks: $1) }
    }
}
