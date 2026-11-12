import Foundation

/// A moment that selects the spots to read (B1): the open of the panel, the wake of the Mac, a tick of the clock of timed
/// reads, a text of the main search, which each spot whose `search.text` pattern matches it answers (A2), or an event with a
/// name and a value (B2-B4). An event with `readsEachSpot` reads each spot that lists it, wanted or not, such as a downloaded
/// update that the app raises.
public enum SpotEvent: Equatable, Sendable {
    case panel
    case wake
    case clock
    case query(String)
    case named(String, value: String?, readsEachSpot: Bool = false)

    /// The event that the Mac raises when another app comes to the front, with its bundle ID as the value (B2).
    public static let frontApp = "app.front"
    /// The event that the Mac raises when the clipboard changes (B2).
    public static let clipboard = "clipboard.change"
    /// The event that the Mac raises when the screen wakes (B2).
    public static let screenWake = "screen.wake"
    /// The event that the app raises when it has downloaded an update, with its version as the value (B2).
    public static let appUpdate = "app.update"

    /// The event of the open of a script's sheet.
    public static let sheetOpen = "sheet.open"
    /// The event of each open of the panel, and of the start of the app.
    public static let panelOpen = "panel.open"
    /// The event of a change of the text of the main search, with the text as its value (A1).
    public static let searchText = "search.text"
    /// The event of a change of the text of the search of a script's sheet, with the text as its value.
    public static let sheetText = "sheet.text"
    /// The start of the name of a clock, such as `clock.60`.
    public static let clockPrefix = "clock."
    /// The events that Openspot raises.
    public static let known = [sheetOpen, panelOpen, searchText, sheetText, clipboard, frontApp, appUpdate, screenWake]

    /// Whether a word names an event: words of letters, digits, `-` and `_` joined by dots, such as `music.track`, that
    /// start with a letter.
    public static func isName(_ word: String) -> Bool {
        let parts = word.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1, parts.first?.first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }
}
