import Foundation

/// What the Mac gives through the frameworks that Core does not import: EventKit, the apps that open, the settings of the
/// app, and the events of the Mac with the count of changes of the clipboard (B2). A test gives a Mac of its own.
public protocol Mac: AnyObject, Sendable {
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
    /// The guide to building a spot, which `openspot guide` prints.
    var guide: URL? { get }
    /// Calls `heard` with `wake`, `app.front` and `screen.wake` each time one occurs.
    @MainActor func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void)
    /// The count of changes of the clipboard, which each copy makes larger.
    @MainActor var clipboardCount: Int { get }
}

extension Mac {
    public var login: LoginItem? { nil }
    public var link: CommandLink? { nil }
    public var guide: URL? { Bundle.main.url(forResource: "GUIDE", withExtension: "md") }
    /// A Mac with no events hears none.
    @MainActor public func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {}
    @MainActor public var clipboardCount: Int { 0 }
}
