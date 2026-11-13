import AppKit
import OpenspotCore

/// Watches the keys of every app for a tap of one modifier alone, such as Option, through a monitor of the events of other
/// apps and one of the app's own. A monitor of the keys of other apps needs Accessibility. It runs only while a key holds
/// a tap.
@MainActor
final class SpotTapWatch {
    private static let spoils: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]

    private let onTap: @MainActor (Shortcut.Modifiers) -> Void
    private var tap = ModifierTap()
    private var monitors: [Any] = []

    init(onTap: @escaping @MainActor (Shortcut.Modifiers) -> Void) {
        self.onTap = onTap
        let kinds = Self.spoils.union(.flagsChanged)
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: kinds) { [weak self] event in
                MainActor.assumeIsolated { self?.take(event) }
            },
            NSEvent.addLocalMonitorForEvents(matching: kinds) { [weak self] event in
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
        guard event.type == .flagsChanged else { return tap.spoil() }
        if let modifier = tap.take(SpotsPanel.modifiers(of: event.modifierFlags), at: event.timestamp) { onTap(modifier) }
    }
}
