/// What the person said when macOS asked them to let Openspot use their calendars or reminders.
public enum CalendarAccess: Sendable {
    case unasked
    case allowed
    /// No, or less than full access, such as leave only to add events.
    case denied

    /// The text that a read prints while the person has not been asked (E7).
    static let unaskedText = "status=unasked\n"
}
