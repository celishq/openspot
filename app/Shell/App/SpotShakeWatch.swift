import AppKit
import OpenspotCore

/// Watches the pointer for a shake, with or without a drag, through a listen-only tap on its own thread (W2). It reads the
/// pointer and not the keys, so it needs no permission. It runs only while something takes a shake.
final class SpotShakeWatch: @unchecked Sendable {
    private static let moves: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

    private let onShake: @MainActor () -> Void
    private var shake = PointerShake()
    private var tap: CFMachPort?
    private var loop: CFRunLoop?
    private let ended = DispatchSemaphore(value: 0)

    init(onShake: @escaping @MainActor () -> Void) {
        self.onShake = onShake
    }

    /// Starts the tap on its own thread, and returns once it listens. Returns false when macOS gives no tap.
    func listen() -> Bool {
        let mask = Self.moves.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, info in
            if let info { Unmanaged<SpotShakeWatch>.fromOpaque(info).takeUnretainedValue().take(type, event) }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            CFRunLoopRun()
            ended.signal()
        }
        thread.name = "Openspot shake"
        thread.start()
        ready.wait()
        return true
    }

    /// Stops the tap, and returns once its thread has ended.
    func stop() {
        guard let tap, let loop else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopStop(loop)
        ended.wait()
        self.tap = nil
        self.loop = nil
    }

    private func take(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tap.map { CGEvent.tapEnable(tap: $0, enable: true) }
            return
        }
        guard shake.take(x: event.location.x, at: Double(event.timestamp) / 1_000_000_000) else { return }
        DispatchQueue.main.async { [onShake] in MainActor.assumeIsolated { onShake() } }
    }
}
