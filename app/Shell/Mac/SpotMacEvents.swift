import AppKit
import OpenspotCore

/// The events of the Mac from NSWorkspace and the general pasteboard: the wake of the Mac, another app that comes to the
/// front, with its bundle ID, and the wake of the screen (B2).
@MainActor
final class SpotMacEvents: EventSource {
    private var observers: [NSObjectProtocol] = []

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
