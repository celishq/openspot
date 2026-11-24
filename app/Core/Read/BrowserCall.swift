import Foundation

enum BrowserCall: NounCall {
    case tab

    static let noun = CommandNoun("browser", group: .mac, verbs: [
        CommandVerb("tab", "", "Prints the url=, title= and app= of the front tab when a browser is in front, or nothing.", rule: ReadSources.rule) { $0.none ? Self.tab : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        ReadSources.work(in: context) { try await $0.tab(asks: $1) }
    }
}
