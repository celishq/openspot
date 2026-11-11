import Foundation

/// What the API reaches through the frameworks of the Mac that Core does not import: EventKit and the apps that open.
public protocol CommandHost: Sendable {
    func eventStore() -> any EventStore
    func reminderStore() -> any ReminderStore
    /// Opens Calendar on the day of a time.
    func showCalendar(at time: Date) throws
    /// Opens a link in its app, and returns whether it opened.
    func open(_ link: URL) -> Bool
    /// The setting that opens the app at login, when the Mac can register it.
    var login: LoginItem? { get }
    /// The link that puts `openspot` on the path of a terminal.
    var link: CommandLink? { get }
}

extension CommandHost {
    public var login: LoginItem? { nil }
    public var link: CommandLink? { nil }
}
