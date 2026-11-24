import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class Toasts {
    public static let limit = 20
    public static let duration: TimeInterval = 5

    public private(set) var queue: [Toast] = []
    public private(set) var front: Toast?
    public private(set) var isShown = false
    public private(set) var frontSize = CGSize.zero
    public private(set) var count = 0
    public private(set) var leadKind: ToastKind?
    @ObservationIgnored public private(set) var width: CGFloat = 0
    @ObservationIgnored public private(set) var height: CGFloat = 0
    @ObservationIgnored private var target = CGSize.zero
    @ObservationIgnored public weak var window: ToastWindow?
    @ObservationIgnored private let clock: RunClock
    @ObservationIgnored private var lastMade = 0
    @ObservationIgnored private var ends: [ToastID: Task<Void, Never>] = [:]
    @ObservationIgnored private var hiding: Task<Void, Never>?
    @ObservationIgnored private var isHeld = false
    @ObservationIgnored private var fixKeyToast: ToastID?

    public init(clock: RunClock = RunClock()) {
        self.clock = clock
    }

    public func add(_ note: ToastNote, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil) {
        let id = ToastID(spot: spot, name: note.id.map(ToastID.Name.given) ?? .made(nextMade()))
        let existing = queue.first { $0.id == id }
        let isFront = existing == nil || front?.id == id
        let held = isFront ? key.flatMap { holdFixKey(id, key: $0) } : nil
        let words = held.map { "\(note.words) Press `\($0.label)` to fix it." } ?? note.words
        let toast = existing ?? Toast(id: id, note: note, words: words)
        existing?.take(note, words: words)
        toast.duration = note.kind == .work ? nil : Self.duration
        toast.press = press
        toast.fixKey = key
        toast.size = window?.measure(toast) ?? .zero
        if existing == nil {
            queue.insert(toast, at: 0)
            dropped(by: toast).forEach(forget)
        }
        update()
        if existing != nil, front?.id == id, !isHeld { end(toast) }
    }

    public func drop(_ id: String, of spot: String) {
        leave(ToastID(spot: spot, name: .given(id)))
    }

    public func press(_ id: ToastID) {
        queue.first { $0.id == id }?.press?()
        leave(id)
    }

    public func hold(_ isHovered: Bool) {
        guard isHovered != isHeld else { return }
        isHeld = isHovered
        if isHovered {
            ends.values.forEach { $0.cancel() }
            ends.removeAll()
        } else if let front = queue.first {
            end(front)
        }
    }

    private func nextMade() -> Int {
        lastMade += 1
        return lastMade
    }

    private func dropped(by toast: Toast) -> [ToastID] {
        let giving = queue.filter { $0 !== toast && $0.id.spot == toast.id.spot && $0.note.kind == .work }.map(\.id)
        let staying = queue.filter { !giving.contains($0.id) }
        return giving + staying.dropFirst(Self.limit).map(\.id)
    }

    private func leave(_ id: ToastID) {
        guard queue.contains(where: { $0.id == id }) else { return }
        forget(id)
        update()
    }

    private func forget(_ id: ToastID) {
        ends.removeValue(forKey: id)?.cancel()
        queue.removeAll { $0.id == id }
    }

    private func update() {
        let next = queue.first
        if let next {
            hiding?.cancel()
            hiding = nil
            if next !== front {
                front = next
                cut(to: next)
            }
            if isShown {
                window?.move({ fit() }, completion: { [weak self] in self?.shrink() })
            } else {
                fit()
                shrink()
                window?.bringToFront()
                window?.nextFrame { [weak self] in
                    guard let self, front === next, !isShown else { return }
                    isShown = true
                }
            }
        } else if isShown {
            isShown = false
            cut(to: nil)
            hiding = after(MotionTokens.fadeOut) { [weak self] in
                guard let self, queue.isEmpty else { return }
                front = nil
                isHeld = false
                window?.putAway()
            }
        }
        let kind = next?.note.kind
        if kind != leadKind { leadKind = kind }
    }

    private func cut(to toast: Toast?) {
        ends.values.forEach { $0.cancel() }
        ends.removeAll()
        if let toast, !isHeld { end(toast) }
        if let toast, let key = toast.fixKey {
            if fixKeyToast != toast.id { holdFixKey(toast.id, key: key) }
        } else if fixKeyToast != nil {
            window?.dropFixKey()
            fixKeyToast = nil
        }
    }

    private func fit() {
        let size = front?.size ?? .zero
        if size != frontSize { frontSize = size }
        let next = queue.count > 1 ? queue.count : 0
        if next != count { count = next }
        target = size
        guard target.width > width || target.height > height else { return }
        width = max(width, target.width)
        height = max(height, target.height)
        window?.place()
    }

    private func shrink() {
        guard width != target.width || height != target.height else { return }
        width = target.width
        height = target.height
        window?.place()
    }

    private func end(_ toast: Toast) {
        guard let duration = toast.duration else { return }
        let id = toast.id
        ends[id]?.cancel()
        ends[id] = after(duration) { [weak self] in self?.leave(id) }
    }

    @discardableResult
    private func after(_ seconds: TimeInterval, _ body: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task { [clock] in
            do { try await clock.sleep(.seconds(seconds), .seconds(seconds) / 10) } catch { return }
            guard !Task.isCancelled else { return }
            body()
        }
    }

    @discardableResult
    private func holdFixKey(_ id: ToastID, key: Shortcut) -> Shortcut? {
        window?.dropFixKey()
        fixKeyToast = nil
        guard window?.holdFixKey(key, press: { [weak self] in self?.press(id) }) == true else { return nil }
        fixKeyToast = id
        return key
    }
}
