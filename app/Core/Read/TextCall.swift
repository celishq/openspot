import Foundation

enum TextCall: NounCall {
    case selected(String)

    static let noun = CommandNoun("text", group: .mac, verbs: [
        CommandVerb(
            "selected", "<bundle id>",
            "Prints the text= selected in the app that the bundle ID names, and its app=. It prints nothing when the app is not running or has no selection.",
            rule: ReadSources.rule
        ) { $0.one.map(Self.selected) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .selected(let bundleID): ReadSources.work(in: context) { try await $0.selection(of: bundleID, asks: $1) }
        }
    }
}
