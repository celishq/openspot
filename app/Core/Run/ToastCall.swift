import Foundation

enum ToastCall: NounCall {
    case show(String)

    static let noun = CommandNoun("toast", group: .build, verbs: [
        CommandVerb("", "<words>...", "Shows a short message, even when the panel is closed. It works in a read too.", rule: CallRule(flags: .needsApp)) { words in
            words.none ? nil : Self.show(words.rest.joined(separator: " "))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .show(let text) = self else { return nil }
        return SpotEffect.toast(text).work(in: context, name: "toast")
    }
}
