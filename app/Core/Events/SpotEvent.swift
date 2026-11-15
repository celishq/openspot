import Foundation

public enum SpotEvent: Equatable, Sendable {
    case panel
    case wake
    case sleep
    case clock
    case query(String)
    case named(String, value: String?, readsEachSpot: Bool = false)

    public static let frontApp = "app.front"
    public static let clipboard = "clipboard.change"
    public static let screenWake = "screen.wake"
    public static let appUpdate = "app.update"
    public static let appLaunch = "app.launch"

    public static let sheetOpen = "sheet.open"
    public static let panelOpen = "panel.open"
    public static let searchText = "search.text"
    public static let sheetText = "sheet.text"
    public static let clockPrefix = "clock."
    public static let known = [sheetOpen, panelOpen, searchText, sheetText, clipboard, frontApp, appUpdate, appLaunch, screenWake]
    public static let valueless = [sheetOpen, panelOpen, sheetText, clipboard, screenWake, appLaunch]

    public static func isName(_ word: String) -> Bool {
        let parts = word.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1, parts.first?.first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }
}
