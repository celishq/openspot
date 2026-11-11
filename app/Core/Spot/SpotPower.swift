import Foundation

/// A call of `openspot` that uses a power, with the use that a spot's header names for it (Z3). It reads the words of the
/// call, so that the API and a review of a text that runs nothing know it the same way.
public struct SpotPower: Equatable, Sendable {
    private static let spotWord = "--spot"

    public let use: SpotUse
    /// The noun and the verb of the call, such as `screen.shot`.
    public let name: String
    /// What the call did, as words after the name of a spot, such as `took a screenshot`.
    public let words: String

    /// The power that a call of this spot with these words uses, or nil for a call that needs none, such as a setting of
    /// its own plugin.
    public init?(arguments: [String], of spot: String) {
        guard arguments.count >= 2, let (use, words) = Self.power(arguments, spot: spot) else { return nil }
        self.use = use
        name = "\(arguments[0]).\(arguments[1])"
        self.words = words
    }

    private static func power(_ arguments: [String], spot: String) -> (SpotUse, String)? {
        let other = arguments.firstIndex(of: spotWord).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let isOther = other.map { !isOwn($0, of: spot) } ?? false
        return switch (arguments[0], arguments[1]) {
        case ("app", "login"): (.app, "changed whether Openspot opens at login")
        case ("app", "link"): (.app, "changed the openspot command in Terminal")
        case ("app", "quit"): (.app, "quit Openspot")
        case ("key", "set"): (.app, "changed a key")
        case ("menubar", "on"), ("menubar", "off"): (.app, "changed the menu bar")
        case ("update", "check"): (.update, "checked for an update")
        case ("update", "install"): (.update, "installed an update")
        case ("spot", "add"): (.spots, "added a spot")
        case ("spot", "remove"): (.spots, "removed a spot")
        case ("spot", "on"): (.spots, "turned on a spot")
        case ("spot", "off"): (.spots, "turned off a spot")
        case ("spot", "new"): (.spots, "wrote a new spot")
        case ("spot", "run"): (.spots, "ran a spot")
        case ("spot", "log"): (.spots, "read the calls of a spot")
        case ("setting", "list"): (.settings, "read the settings of each spot")
        case ("setting", "get") where isOther: (.settings, "read a setting of another spot")
        case ("setting", "set") where isOther, ("setting", "change") where isOther: (.settings, "changed a setting of another spot")
        case ("screen", "sources"): (.screen, "listed the screens and windows")
        case ("screen", "shot"): (.screen, "took a screenshot")
        case ("screen", "record"): (.screen, "used a screen recording")
        case ("window", "frame"): (.screen, "read the place of a window")
        case ("window", "move"): (.screen, "moved a window")
        case ("color", "pick"): (.screen, "picked a colour on the screen")
        case ("clipboard", "copy"): (.clipboard, "copied to the clipboard")
        case ("clipboard", "paste"): (.clipboard, "pasted the clipboard")
        case ("calendar", "add"): (.calendar, "added an event")
        case ("calendar", "show"): (.calendar, "opened Calendar")
        case ("calendar", _): (.calendar, "read your calendar")
        case ("reminders", "add"): (.calendar, "added a reminder")
        case ("reminders", "done"): (.calendar, "changed a reminder")
        case ("reminders", "show"): (.calendar, "opened Reminders")
        case ("reminders", _): (.calendar, "read your reminders")
        default: nil
        }
    }

    /// Whether a spot is the caller or a script of the caller's plugin folder, which is one unit.
    private static func isOwn(_ other: String, of spot: String) -> Bool {
        other == spot || (spot.contains("/") && other.split(separator: "/").first == spot.split(separator: "/").first)
    }
}
