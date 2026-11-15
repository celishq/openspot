import AppKit
import OpenspotCore

@MainActor
final class SpotTapWatch {
    private static let spoils: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]

    private let onTap: @MainActor (Shortcut.Modifiers) -> Void
    private var tap = ModifierTap()
    private var monitors: [Any] = []

    init(onTap: @escaping @MainActor (Shortcut.Modifiers) -> Void) {
        self.onTap = onTap
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                MainActor.assumeIsolated { self?.take(event) }
            },
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.take(event)
                return event
            }
        ].compactMap { $0 }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func take(_ event: NSEvent) {
        let presses = Self.spoils.reduce(UInt32(0)) { $0 &+ CGEventSource.counterForEventType(.combinedSessionState, eventType: $1) }
        if let modifier = tap.take(event.keyModifiers, at: event.timestamp, keysDown: presses) { onTap(modifier) }
    }
}
