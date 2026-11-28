import AppKit
import OpenspotCore

@MainActor
final class SpotMac: MacEvents {
    private static let locked = Notification.Name("com.apple.screenIsLocked")
    private static let unlocked = Notification.Name("com.apple.screenIsUnlocked")
    private var observers: [NSObjectProtocol] = []
    private var lockObservers: [NSObjectProtocol] = []
    private var isLocked = false
    private let system = SpotSystemEvents()
    private let calendars = SpotCalendarEvents()

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
        SpotClipboard().count()
    }

    var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func measureLoad() -> LoadSample {
        SpotSystemEvents.measureLoad()
    }

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        system.listen(heard)
        calendars.listen(heard)
        let center = NSWorkspace.shared.notificationCenter
        let screens = DistributedNotificationCenter.default()
        observers.forEach(center.removeObserver)
        lockObservers.forEach(screens.removeObserver)
        lockObservers = [
            screens.addObserver(forName: Self.locked, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isLocked = true
                    heard(.away)
                }
            },
            screens.addObserver(forName: Self.unlocked, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isLocked = false
                    heard(.back)
                }
            }
        ]
        observers = [
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.away) }
            },
            center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.away) }
            },
            center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.back) }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.wake) }
            },
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { heard(.sleep) }
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.isLocked == false { heard(.back) }
                    heard(.named(EventName.screenWake, value: nil))
                }
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
