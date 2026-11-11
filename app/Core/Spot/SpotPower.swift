import Foundation

/// A call of `openspot` that uses a power, with the use that a spot's header names for it (Z3).
public struct SpotPower: Equatable, Sendable {
    public let use: SpotUse
    /// The noun and the verb of the call, such as `screen.shot`.
    public let name: String
    /// What the call did, as words after the name of a spot, such as `took a screenshot`.
    public let words: String

    /// The power that a call of this spot uses, or nil for a call that needs none, such as a setting of its own plugin.
    public init?(_ call: CommandLineCall, of spot: String) {
        guard let (use, name, words) = Self.power(of: call, spot: spot) else { return nil }
        self.use = use
        self.name = name
        self.words = words
    }

    private static func power(of call: CommandLineCall, spot: String) -> (SpotUse, String, String)? {
        switch call {
        case .appLogin: (.app, "app.login", "changed whether Openspot opens at login")
        case .appLink: (.app, "app.link", "changed the openspot command in Terminal")
        case .appQuit: (.app, "app.quit", "quit Openspot")
        case .appKeySet, .keySet: (.app, "key.set", "changed a key")
        case .menuBar: (.app, "menubar", "changed the menu bar")
        case .updateCheck: (.update, "update.check", "checked for an update")
        case .updateInstall: (.update, "update.install", "installed an update")
        case .spotAdd: (.spots, "spot.add", "added a spot")
        case .spotRemove: (.spots, "spot.remove", "removed a spot")
        case .spotTurn(_, true): (.spots, "spot.on", "turned on a spot")
        case .spotTurn(_, false): (.spots, "spot.off", "turned off a spot")
        case .spotNew: (.spots, "spot.new", "wrote a new spot")
        case .spotRun: (.spots, "spot.run", "ran a spot")
        case .spotLog: (.spots, "spot.log", "read the calls of a spot")
        case .settingList: (.settings, "setting.list", "read the settings of each spot")
        case .settingGet(let other, _) where !isOwn(other, of: spot): (.settings, "setting.get", "read a setting of another spot")
        case .settingSet(let other, _, _) where !isOwn(other, of: spot): (.settings, "setting.set", "changed a setting of another spot")
        case .settingChange(let other, _) where !isOwn(other, of: spot): (.settings, "setting.change", "changed a setting of another spot")
        case .screenSources: (.screen, "screen.sources", "listed the screens and windows")
        case .screenShot: (.screen, "screen.shot", "took a screenshot")
        case .screenRecordStart: (.screen, "screen.record", "started a screen recording")
        case .screenRecordStop: (.screen, "screen.record", "stopped a screen recording")
        case .screenRecordStatus: (.screen, "screen.record", "checked a screen recording")
        case .windowFrame: (.screen, "window.frame", "read the place of a window")
        case .windowMove: (.screen, "window.move", "moved a window")
        case .colorPick: (.screen, "color.pick", "picked a colour on the screen")
        case .clipboardCopy: (.clipboard, "clipboard.copy", "copied to the clipboard")
        case .clipboardPaste: (.clipboard, "clipboard.paste", "pasted the clipboard")
        case .calendarEvents: (.calendar, "calendar.events", "read your calendar")
        case .calendarCalendars: (.calendar, "calendar.calendars", "read your calendars")
        case .calendarAdd: (.calendar, "calendar.add", "added an event")
        case .calendarShow: (.calendar, "calendar.show", "opened Calendar")
        case .remindersDue: (.calendar, "reminders.due", "read your reminders")
        case .remindersLists: (.calendar, "reminders.lists", "read your lists of reminders")
        case .remindersAdd: (.calendar, "reminders.add", "added a reminder")
        case .remindersDone: (.calendar, "reminders.done", "changed a reminder")
        case .remindersShow: (.calendar, "reminders.show", "opened Reminders")
        default: nil
        }
    }

    /// Whether a spot is the caller or a script of the caller's plugin folder, which is one unit.
    private static func isOwn(_ other: String, of spot: String) -> Bool {
        other == spot || (spot.contains("/") && other.split(separator: "/").first == spot.split(separator: "/").first)
    }
}
