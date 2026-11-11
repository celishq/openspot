import AppKit
import OpenspotCore

/// What the API and the runs reach through the Mac: EventKit, Calendar, the app that opens a link, the settings of the app,
/// the events of NSWorkspace and the general pasteboard: the wake of the Mac, another app that comes to the front, with its
/// bundle ID, and the wake of the screen (B2), the clipboard and the window in front.
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
        try await SpotWindow.front().frameText()
    }

    nonisolated func moveWindow(_ move: WindowMove) async throws {
        try await SpotWindow.front().move(move)
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
