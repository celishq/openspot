import Foundation

enum SelectionCall: NounCall {
    case read(String)

    static let noun = CommandNoun("selection", group: .mac, verbs: [
        CommandVerb(
            "read", "<app>",
            "Prints what is selected in the app, and its app=: a file= for each file selected in Finder, or the text= selected in another app. It prints nothing when the app is not running or has no selection.",
            rule: ReadSources.selectionRule
        ) { $0.one.map(Self.read) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .read(let app): ReadSources.work(in: context) { try await $0.selection(of: app, asks: $1) }
        }
    }
}
