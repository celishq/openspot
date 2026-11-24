import Foundation

enum BrowserCall: NounCall {
    case tab(String?)
    case tabs(String?)

    static let noun = CommandNoun("browser", group: .mac, verbs: [
        CommandVerb(
            "tab", "[<bundle id>]",
            "Prints the url=, title= and app= of the front tab of the browser in front, or of the browser named by its bundle ID while another app is in front. It prints nothing when no browser is in front or the named one is not running.",
            rule: ReadSources.rule
        ) { Self.parse($0, Self.tab) },
        CommandVerb(
            "tabs", "[<bundle id>]",
            "Prints a record for each tab of each window of the browser in front, or of the browser named by its bundle ID: url=, title=, window= (1 is the front window), index= (its place in the window), active=true or false, and app=.",
            rule: ReadSources.rule
        ) { Self.parse($0, Self.tabs) }
    ])

    private static func parse(_ words: CallWords, _ call: (String?) -> Self) -> (any NounCall)? {
        guard words.rest.count <= 1 else { return nil }
        guard let bundleID = words.one else { return call(nil) }
        return Browser.named(bundleID) == nil ? CallFault.refused(Browser.unknown(bundleID)) : call(bundleID)
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .tab(let bundleID): ReadSources.work(in: context) { try await $0.tab(of: bundleID, asks: $1) }
        case .tabs(let bundleID): ReadSources.work(in: context) { try await $0.tabs(of: bundleID, asks: $1) }
        }
    }
}
