import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class Toasts {
    public static let limit = 3
    public static let duration: TimeInterval = 5

    public private(set) var shown: [Toast] = []
    public private(set) var lead: ToastKind?
    public private(set) var places: [ToastID: ToastLayout.Place] = [:]
    public private(set) var width: CGFloat?
    @ObservationIgnored public private(set) var height: CGFloat = 0
    @ObservationIgnored public private(set) var isExpanded = false
    @ObservationIgnored public weak var window: ToastWindow?
    @ObservationIgnored private unowned let host: SpotsHost
    @ObservationIgnored private let clock: RunClock
    @ObservationIgnored private var count = 0
    @ObservationIgnored private var leaving: Set<ToastID> = []
    @ObservationIgnored private var ends: [ToastID: Task<Void, Never>] = [:]
    @ObservationIgnored private var isHeld = false
    @ObservationIgnored private var fixHolder: ToastID?

    public init(host: SpotsHost, clock: RunClock = RunClock()) {
        self.host = host
        self.clock = clock
    }

    public func add(_ note: ToastNote, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = Toasts.duration) {
        let id = ToastID(spot: spot, name: note.id.map(ToastID.Name.given) ?? .made(next()))
        let existing = stacked.first { $0.id == id }
        if existing == nil, leaving.remove(id) != nil { shown.removeAll { $0.id == id } }
        let fixKey = press == nil ? nil : key
        let held = fixKey.flatMap { holdFixKey(id, key: $0) }
        let words = held.map { "\(note.words) Press `\($0.label)` to fix it." } ?? note.words
        let toast = existing ?? Toast(id: id, note: note, words: words)
        existing?.take(note, words: words)
        toast.duration = note.keeps || note.kind == .work ? nil : duration
        toast.press = press
        toast.fixKey = fixKey
        if existing == nil { dropped(by: toast).forEach(leave) }
        toast.size = window?.measure(toast) ?? .zero
        if existing == nil { shown.insert(toast, at: 0) }
        widen()
        host.change(.move, { arrange() }, completion: {})
        window?.place()
        if existing == nil {
            window?.bringToFront()
            window?.nextFrame { [weak self] in
                guard let self, isStacked(id) else { return }
                toast.isShown = true
                takeLead()
            }
        }
        ends.removeValue(forKey: id)?.cancel()
        if !isHeld { end(toast) }
    }

    public func drop(_ id: String, of spot: String) {
        leave(ToastID(spot: spot, name: .given(id)))
    }

    public func press(_ id: ToastID) {
        shown.first { $0.id == id }?.press?()
        leave(id)
    }

    public func hold(_ isHovered: Bool) {
        guard isHovered != isHeld else { return }
        isHeld = isHovered
        if isHovered {
            ends.values.forEach { $0.cancel() }
            ends.removeAll()
        } else {
            stacked.forEach(end)
        }
        isExpanded = isHovered
        host.change(.move, { arrange() }, completion: {})
        if isHovered {
            window?.place()
        } else {
            after(MotionTokens.move) { [weak self] in
                guard let self, !isHeld else { return }
                window?.place()
            }
        }
    }

    private var stacked: [Toast] {
        shown.filter { !leaving.contains($0.id) }
    }

    private func isStacked(_ id: ToastID) -> Bool {
        shown.contains { $0.id == id } && !leaving.contains(id)
    }

    private func next() -> Int {
        count += 1
        return count
    }

    private func dropped(by toast: Toast) -> [ToastID] {
        let stacked = stacked
        let giving = stacked.filter { $0.id.spot == toast.id.spot && $0.note.kind == .work }.map(\.id)
        let staying = stacked.filter { !giving.contains($0.id) }
        return giving + staying.dropFirst(Self.limit - 1).map(\.id)
    }

    private func leave(_ id: ToastID) {
        ends.removeValue(forKey: id)?.cancel()
        guard let toast = shown.first(where: { $0.id == id }), leaving.insert(id).inserted else { return }
        if toast.isShown { toast.isShown = false }
        takeLead()
        if fixHolder == id { passFixKey() }
        after(MotionTokens.fadeOut) { [weak self] in
            guard let self, shown.contains(where: { $0 === toast }) else { return }
            leaving.remove(id)
            host.change(.move, {
                shown.removeAll { $0.id == id }
                arrange()
            }, completion: {})
            after(MotionTokens.move) { [weak self] in self?.settle() }
        }
    }

    private func settle() {
        widen()
        if !stacked.isEmpty {
            window?.place()
        } else if shown.isEmpty {
            isHeld = false
            window?.putAway()
        }
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
            do { try await clock.sleep(.seconds(seconds), nil) } catch { return }
            guard !Task.isCancelled else { return }
            body()
        }
    }

    @discardableResult
    private func holdFixKey(_ id: ToastID, key: Shortcut) -> Shortcut? {
        window?.dropFixKey()
        fixHolder = nil
        guard window?.holdFixKey(key, press: { [weak self] in self?.press(id) }) == true else { return nil }
        fixHolder = id
        return key
    }

    private func passFixKey() {
        window?.dropFixKey()
        fixHolder = nil
        guard let next = stacked.first(where: { $0.fixKey != nil }), let key = next.fixKey else { return }
        holdFixKey(next.id, key: key)
    }

    private func takeLead() {
        let next = shown.first { $0.isShown }?.note.kind
        if next != lead { lead = next }
    }

    private func widen() {
        let next = shown.map(\.size.width).max()
        if next != width { width = next }
    }

    private func arrange() {
        let layout = ToastLayout(heights: shown.map(\.size.height), isExpanded: isExpanded)
        let next = Dictionary(uniqueKeysWithValues: zip(shown.map(\.id), layout.places))
        if next != places { places = next }
        height = layout.height
    }
}
