import Foundation

enum BrowserCall: NounCall {
    case tab(Browser)
    case tabs(Browser)

    static let noun = CommandNoun("browser", group: .mac, verbs: [
        CommandVerb(
            "tab", "<app>",
            "Prints the url=, title= and app= of the front tab of the front window of the browser <app>. It prints nothing when that browser is not running.",
            rule: ReadSources.rule
        ) { Self.parse($0, Self.tab) },
        CommandVerb(
            "tabs", "<app>",
            "Prints a record for each tab of each window of the browser <app>: url=, title=, window= (1 is the front window), index= (its place in the window), active=true or false, and app=.",
            rule: ReadSources.rule
        ) { Self.parse($0, Self.tabs) }
    ])

    private static func parse(_ words: CallWords, _ call: (Browser) -> Self) -> (any NounCall)? {
        guard let bundleID = words.one else { return nil }
        return Browser.named(bundleID).map(call) ?? CallFault.refused(Browser.unknown(bundleID))
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .tab(let browser): ReadSources.work(in: context) { try await $0.tab(of: browser, asks: $1) }
        case .tabs(let browser): ReadSources.work(in: context) { try await $0.tabs(of: browser, asks: $1) }
        }
    }
}
