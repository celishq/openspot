import Foundation

public struct Mac: Sendable {
    public var calendar: (any MacCalendar)?
    public var reminders: (any MacReminders)?
    public var clipboard: (any MacClipboard)?
    public var windows: (any MacWindows)?
    public var screen: (any MacScreen)?
    public var translation: (any MacTranslation)?
    public var events: (any MacEvents)?
    public var login: @Sendable () -> LoginItem?
    public var link: @Sendable () -> CommandLink?
    public var pickColor: (@MainActor @Sendable () async -> HexColor?)?
    public var pickFolder: (@MainActor @Sendable () async -> URL?)?
    public var guide: URL?
    public var theme: ThemeFile

    public init(
        calendar: (any MacCalendar)? = nil,
        reminders: (any MacReminders)? = nil,
        clipboard: (any MacClipboard)? = nil,
        windows: (any MacWindows)? = nil,
        screen: (any MacScreen)? = nil,
        translation: (any MacTranslation)? = nil,
        events: (any MacEvents)? = nil,
        login: @escaping @Sendable () -> LoginItem? = { nil },
        link: @escaping @Sendable () -> CommandLink? = { nil },
        pickColor: (@MainActor @Sendable () async -> HexColor?)? = nil,
        pickFolder: (@MainActor @Sendable () async -> URL?)? = nil,
        guide: URL? = Bundle.main.url(forResource: "GUIDE", withExtension: "md"),
        theme: ThemeFile = .builtIn
    ) {
        self.calendar = calendar
        self.reminders = reminders
        self.clipboard = clipboard
        self.windows = windows
        self.screen = screen
        self.translation = translation
        self.events = events
        self.login = login
        self.link = link
        self.pickColor = pickColor
        self.pickFolder = pickFolder
        self.guide = guide
        self.theme = theme
    }

    static func part<Part>(_ part: Part?, _ name: String) throws -> Part {
        guard let part else { throw SpotError.fault("This Mac has no \(name).") }
        return part
    }
}
