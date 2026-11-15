import Foundation

public protocol Mac: AnyObject, Sendable {
    func eventStore() -> any EventStore
    func reminderStore() -> any ReminderStore
    func showCalendar(at time: Date) throws
    func open(_ link: URL) -> Bool
    var login: LoginItem? { get }
    var link: CommandLink? { get }
    var guide: URL? { get }
    @MainActor func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void)
    @MainActor var clipboardCount: Int { get }
    func copy(text: String) throws
    func copy(file: URL) throws
    func clipboardText() -> String
    func paste() throws
    func windowFrame() async throws -> String
    func moveWindow(_ move: WindowMove) async throws
    func screenSources() async -> String
    func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String
    func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String
    func stopRecording() async throws -> String
    func recordingStatus() async throws -> String
    func translate(_ text: String, from: String?, to: String?) async throws -> String
    func translationLanguages() async -> String
    @MainActor func pickColor() async -> String
    @MainActor func pickFolder() async -> String
}

extension Mac {
    public var login: LoginItem? { nil }
    public var link: CommandLink? { nil }
    public var guide: URL? { Bundle.main.url(forResource: "GUIDE", withExtension: "md") }
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
