import AppKit
import OpenspotCore

/// Watches the pointer for a shake, with or without a drag, through a monitor of the events of other apps and one of the
/// app's own (W2). A monitor of the pointer needs no permission, as one of the keys would. It runs only while something
/// takes a shake.
@MainActor
final class SpotShakeWatch {
    private static let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

    private let onShake: @MainActor () -> Void
    private var shake = PointerShake()
    private var monitors: [Any] = []

    init(onShake: @escaping @MainActor () -> Void) {
        self.onShake = onShake
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: Self.moves) { [weak self] event in
                MainActor.assumeIsolated { self?.take(event) }
            },
            NSEvent.addLocalMonitorForEvents(matching: Self.moves) { [weak self] event in
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
        let x = event.window.map { $0.convertPoint(toScreen: event.locationInWindow).x } ?? event.locationInWindow.x
        if shake.take(x: x, at: event.timestamp) { onShake() }
    }
}
