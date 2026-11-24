import Foundation

enum BrowserCall: NounCall {
    case tab(String)
    case tabs(String)

    static let noun = CommandNoun("browser", group: .mac, verbs: [
        CommandVerb(
            "tab", "<app>",
            "Prints the url=, title= and app= of the front tab of the front window of the browser <app>. It prints nothing when that browser is not running.",
            rule: ReadSources.rule
        ) { $0.one.map(Self.tab) },
        CommandVerb(
            "tabs", "<app>",
            "Prints a record for each tab of each window of the browser <app>: url=, title=, window= (1 is the front window), index= (its place in the window), active=true or false, and app=.",
            rule: ReadSources.rule
        ) { $0.one.map(Self.tabs) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let config = context.places.config
        return switch self {
        case .tab(let app): ReadSources.work(in: context) { try await $0.tab(of: app, in: config.read().browsers, asks: $1) }
        case .tabs(let app): ReadSources.work(in: context) { try await $0.tabs(of: app, in: config.read().browsers, asks: $1) }
        }
    }
}
