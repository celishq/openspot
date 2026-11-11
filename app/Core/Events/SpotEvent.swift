import Foundation

/// A moment that selects the spots to read (B1): the open of the panel, the wake of the Mac, a text of the main search,
/// which each spot whose `answers` pattern matches it answers (A2), or an event with a name and a value (B2-B4).
public enum SpotEvent: Equatable, Sendable {
    case panel
    case wake
    case query(String)
    case named(String, value: String?)

    /// The event that the Mac raises when another app comes to the front, with its bundle ID as the value (B2).
    public static let frontApp = "app.front"
    /// The event that the Mac raises when the clipboard changes (B2).
    public static let clipboard = "clipboard"
    /// The event that the Mac raises when the screen wakes (B2).
    public static let screenWake = "screen.wake"
    /// The event that the app raises when it has downloaded an update, with its version as the value (B2).
    public static let appUpdate = "app.update"

    /// Whether a word names an event: `clipboard`, or words of letters, digits, `-` and `_` joined by dots, such as
    /// `music.track`, that start with a letter.
    public static func isName(_ word: String) -> Bool {
        if word == clipboard { return true }
        let parts = word.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1, parts.first?.first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }
}
