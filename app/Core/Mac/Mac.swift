import Foundation

/// What the Mac gives through the frameworks that Core does not import: EventKit, the apps that open, the settings of the
/// app, the events of the Mac with the count of changes of the clipboard (B2), the clipboard, the window in front, the
/// screen, translation and the picks of a colour and a folder. A test gives a Mac of its own. A member with no `@MainActor` runs on the thread of its call, never on the main thread of the app.
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
    /// Puts the text on the clipboard.
    func copy(text: String) throws
    /// Puts the file on the clipboard as Finder copies it, with the picture of an image.
    func copy(file: URL) throws
    /// The text on the clipboard, or nothing when it holds none.
    func clipboardText() -> String
    /// Presses `⌘V` in the front app.
    func paste() throws
    /// The focused window of the front app, then the usable area of its screen, as one line of eight whole numbers.
    func windowFrame() async throws -> String
    /// Moves the focused window of the front app.
    func moveWindow(_ move: WindowMove) async throws
    /// Each display, window, sound, microphone and camera, as a row whose id is its source or input word.
    func screenSources() async -> String
    /// Takes a picture of the source, and returns the path of its file on a line, or nothing after a cancel of the pick. A
    /// relative file starts in `folder`.
    func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String
    /// Starts a recording of the source, which the screen helper keeps until a stop (S10). A relative file starts in `folder`.
    func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String
    /// Ends the recording, and returns each of its files on a line, the video first.
    func stopRecording() async throws -> String
    func recordingStatus() async throws -> String
    /// Translates the text in the translate helper (K2), and returns the block that says what happened.
    func translate(_ text: String, from: String?, to: String?) async throws -> String
    /// The languages that the person prefers, then a block for each language that the Mac translates.
    func translationLanguages() async -> String
    /// Shows the colour sampler of macOS, and returns the picked colour on a line, or nothing after a cancel.
    @MainActor func pickColor() async -> String
    /// Shows the folder window of macOS, and returns the picked folder on a line, or nothing after a cancel.
    @MainActor func pickFolder() async -> String
}

extension Mac {
    public var login: LoginItem? { nil }
    public var link: CommandLink? { nil }
    public var guide: URL? { Bundle.main.url(forResource: "GUIDE", withExtension: "md") }
    /// A Mac with no events hears none.
    @MainActor public func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {}
    @MainActor public var clipboardCount: Int { 0 }
    public func copy(text: String) throws { throw SpotError.fault("This Mac has no clipboard.") }
    public func copy(file: URL) throws { throw SpotError.fault("This Mac has no clipboard.") }
    public func clipboardText() -> String { "" }
    public func paste() throws { throw SpotError.fault("This Mac has no clipboard.") }
    public func windowFrame() async throws -> String { throw SpotError.fault("This Mac has no windows.") }
    public func moveWindow(_ move: WindowMove) async throws { throw SpotError.fault("This Mac has no windows.") }
    public func screenSources() async -> String { "" }
    public func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String { throw SpotError.fault("This Mac has no screen.") }
    public func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String { throw SpotError.fault("This Mac has no screen.") }
    public func stopRecording() async throws -> String { throw SpotError.fault("This Mac has no screen.") }
    public func recordingStatus() async throws -> String { throw SpotError.fault("This Mac has no screen.") }
    public func translate(_ text: String, from: String?, to: String?) async throws -> String { throw SpotError.fault("This Mac cannot translate.") }
    public func translationLanguages() async -> String { "" }
    @MainActor public func pickColor() async -> String { "" }
    @MainActor public func pickFolder() async -> String { "" }
}
