import Foundation

enum FinderCall: NounCall {
    case selection

    static let noun = CommandNoun("finder", group: .mac, verbs: [
        CommandVerb("selection", "", "Prints a file= for each file selected in Finder, and app=.", rule: ReadSources.rule) { $0.none ? Self.selection : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        ReadSources.work(in: context) { try await $0.finder(asks: $1) }
    }
}
