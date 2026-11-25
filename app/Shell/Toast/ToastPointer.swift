import AppKit

@MainActor
final class ToastPointer {
    private static let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

    private let area: @MainActor () -> CGRect
    private let onChange: @MainActor (Bool) -> Void
    private var monitors: [Any] = []
    private var isInside = false

    init(area: @escaping @MainActor () -> CGRect, onChange: @escaping @MainActor (Bool) -> Void) {
        self.area = area
        self.onChange = onChange
    }

    func start() {
        guard monitors.isEmpty else { return }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: Self.moves) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            },
            NSEvent.addLocalMonitorForEvents(matching: Self.moves) { [weak self] event in
                self?.check()
                return event
            }
        ].compactMap { $0 }
        check()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if isInside {
            isInside = false
            onChange(false)
        }
    }

    func check() {
        let inside = area().contains(NSEvent.mouseLocation)
        guard inside != isInside else { return }
        isInside = inside
        onChange(inside)
    }
}
