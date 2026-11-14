import Foundation

/// A call of `openspot` that needs a use, with the use that a spot's header names for it (protocol: Trust). It reads the words of the
/// call, so that the API and a review of a text that runs nothing know it the same way.
public struct SpotUseCall: Equatable, Sendable {
    private static let spotWord = "--spot"

    public let use: SpotUse
    /// The noun and the verb of the call, such as `screen.shot`.
    public let name: String
    /// What the call did, as words after the name of a spot, such as `took a screenshot`.
    public let words: String

    /// The use that a call of this spot with these words needs, or nil for a call that needs none, such as a setting of its
    /// own spot folder.
    public init?(arguments: [String], of spot: String) {
        let arguments = ReservedSetting.words(of: arguments, spot: spot)
        guard arguments.count >= 2, let (use, words) = Self.use(arguments, spot: spot) else { return nil }
        self.use = use
        name = "\(arguments[0]).\(arguments[1])"
        self.words = words
    }

    private static func use(_ arguments: [String], spot: String) -> (SpotUse, String)? {
        let other = arguments.firstIndex(of: spotWord).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let isOther = other.map { !isOwn($0, of: spot) } ?? false
        return switch (arguments[0], arguments[1]) {
        case ("app", "login"): (.app, "changed whether Openspot opens at login")
        case ("app", "link"): (.app, "changed the openspot command in Terminal")
        case ("app", "careful"): (.app, "changed Careful mode")
        case ("app", "quit"): (.app, "quit Openspot")
        case ("key", "set"): (.app, "changed a key")
        case ("menubar", "on"), ("menubar", "off"): (.app, "changed the menu bar")
        case ("update", "check"): (.app, "checked for an update")
        case ("update", "install"): (.app, "installed an update")
        case ("account", "sync"), ("account", "new"), ("account", "words"), ("account", "check"), ("account", "checked"),
             ("account", "phrase"), ("account", "sign-in"), ("account", "sign-out"): (.account, "reached your account key")
        case ("spot", "add"): (.spots, "added a spot")
        case ("store", "list"): (.spots, "read the store")
        case ("store", "publish"): (.account, "published a spot")
        case ("spot", "remove"): (.spots, "removed a spot")
        case ("spot", "edit"): (.spots, "opened the file of a spot")
        case ("spot", "prompt"): (.spots, "copied a prompt to change a spot")
        case ("spot", "share"): (.spots, "shared a spot")
        case ("spot", "delete"): (.spots, "deleted a spot")
        case ("spot", "on"): (.spots, "turned on a spot")
        case ("spot", "off"): (.spots, "turned off a spot")
        case ("spot", "new"): (.spots, "wrote a new spot")
        case ("spot", "run"): (.spots, "ran a spot")
        case ("spot", "log"): (.spots, "read the calls of a spot")
        case ("setting", "list"): (.spots, "read the settings of each spot")
        case ("setting", "get") where isOther: (.spots, "read a setting of another spot")
        case ("setting", "set") where isOther, ("setting", "change") where isOther: (.spots, "changed a setting of another spot")
        case ("screen", "sources"): (.screen, "listed the screens and windows")
        case ("screen", "shot"): (.screen, "took a screenshot")
        case ("screen", "record"): (.screen, "used a screen recording")
        case ("window", "frame"): (.screen, "read the place of a window")
        case ("window", "move"): (.screen, "moved a window")
        case ("color", "pick"): (.screen, "picked a colour on the screen")
        case ("clipboard", "copy"): (.clipboard, "copied to the clipboard")
        case ("clipboard", "paste"): (.clipboard, "pasted the clipboard")
        case ("clipboard", "read"): (.clipboard, "read the clipboard")
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

    /// Whether a spot is the caller or a script of the caller's spot folder, which is one unit.
    private static func isOwn(_ other: String, of spot: String) -> Bool {
        SpotID(other).isSameFolder(as: SpotID(spot))
    }
}
