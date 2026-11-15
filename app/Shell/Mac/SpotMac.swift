import AppKit
import OpenspotCore

@MainActor
final class SpotMac: Mac {
    private var observers: [NSObjectProtocol] = []

    nonisolated func eventStore() -> any EventStore {
        SpotEventStore()
    }

    nonisolated func reminderStore() -> any ReminderStore {
        SpotReminderStore()
    }

    nonisolated func showCalendar(at time: Date) throws {
        _ = try SpotCalendarApp.show(time)
    }

    nonisolated func open(_ link: URL) -> Bool {
        NSWorkspace.shared.open(link)
    }

    nonisolated var login: LoginItem? {
        AppLogin.item
    }

    nonisolated var link: CommandLink? {
        AppCommandLink.item
    }

    nonisolated func copy(text: String) throws {
        try SpotClipboard.copy(text: text)
    }

    nonisolated func copy(file: URL) throws {
        try SpotClipboard.copy(file)
    }

    nonisolated func clipboardText() -> String {
        SpotClipboard.text()
    }

    nonisolated func paste() throws {
        try SpotClipboard.paste()
    }

    nonisolated func windowFrame() async throws -> String {
        try await SpotBlocking.run { try SpotWindow.front().frameText }
    }

    nonisolated func moveWindow(_ move: WindowMove) async throws {
        try await SpotBlocking.run { try SpotWindow.front().move(move) }
    }

    nonisolated func screenSources() async -> String {
        await SpotScreen.sources()
    }

    nonisolated func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String {
        try await SpotScreen.shot(capture, in: folder)
    }

    nonisolated func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String {
        try await SpotRecording.start(capture, in: folder)
    }

    nonisolated func stopRecording() async throws -> String {
        try await SpotBlocking.run { try SpotRecording.stop() }
    }

    nonisolated func recordingStatus() async throws -> String {
        try await SpotBlocking.run { try SpotRecording.status() }
    }

    nonisolated func translate(_ text: String, from: String?, to: String?) async throws -> String {
        try await SpotBlocking.run { try SpotTranslation.call(text: text, from: from, to: to) }
    }

    nonisolated func translationLanguages() async -> String {
        await SpotTranslation.languages()
    }

    func pickColor() async -> String {
        await SpotColorPick.pick()
    }

    func pickFolder() async -> String {
        await SpotFolderPick.pick()
    }

    var clipboardCount: Int {
        NSPasteboard.general.changeCount
    }

    func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers = [
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.wake) }
            },
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.sleep) }
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.named(SpotEvent.screenWake, value: nil)) }
            },
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                let value = app.bundleIdentifier ?? app.localizedName
                MainActor.assumeIsolated { heard(.named(SpotEvent.frontApp, value: value)) }
            }
        ]
    }
}
