import AppKit
import OpenspotCore

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
