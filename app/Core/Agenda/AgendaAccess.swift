/// What the person said when macOS asked them to let Openspot use their calendars or reminders.
public enum AgendaAccess: Sendable {
    case unasked
    case allowed
    /// No, or less than full access, such as leave only to add events.
    case denied
}
