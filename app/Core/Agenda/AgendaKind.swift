import Foundation

/// The two kinds of thing in an agenda, each with its own leave from the person and its own pane in System Settings.
public enum AgendaKind: Sendable {
    case event
    case reminder

    /// The pane of Privacy & Security where the person gives Openspot this leave (E8).
    public var pane: URL {
        switch self {
        case .event: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        case .reminder: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
        }
    }

    /// The line that says that Openspot has no leave, and how to give it.
    var refusal: String {
        switch self {
        case .event: "Openspot has no access to your calendars. Allow Openspot in Privacy & Security › Calendars, then try again."
        case .reminder: "Openspot has no access to your reminders. Allow Openspot in Privacy & Security › Reminders, then try again."
        }
    }
}
