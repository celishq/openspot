import AppKit
import OpenspotCore

@MainActor
final class SpotMac: MacEvents {
    private var observers: [NSObjectProtocol] = []
    private let system = SpotSystemEvents()

    nonisolated var mac: Mac {
        Mac(
            calendar: SpotCalendarApp(),
            reminders: SpotRemindersApp(),
            clipboard: SpotClipboard(),
            windows: SpotWindows(),
            screen: SpotScreen(),
            translation: SpotTranslation(),
            events: self,
            power: SpotPower(),
            accesses: SpotAccesses(),
            login: { AppLogin.item },
            link: { AppCommandLink.item },
            pickColor: { await SpotColorPick.pick() },
            pickFolder: { await SpotFolderPick.pick() },
            openText: { SpotTextEditor.open($0) }
        )
    }

    var clipboardCount: Int {
        NSPasteboard.general.changeCount
    }

    func measureLoad() -> LoadSample {
        SpotSystemEvents.measureLoad()
    }

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        system.listen(heard)
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
                MainActor.assumeIsolated { heard(.named(EventName.screenWake, value: nil)) }
            },
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                let value = app.bundleIdentifier ?? app.localizedName
                MainActor.assumeIsolated { heard(.named(EventName.frontApp, value: value)) }
            }
        ]
    }
}
