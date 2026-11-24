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
    public private(set) var places: [Int: ToastLayout.Place] = [:]
    public private(set) var width: CGFloat?
    @ObservationIgnored public private(set) var height: CGFloat = 0
    @ObservationIgnored public private(set) var isExpanded = false
    @ObservationIgnored public weak var window: ToastWindow?
    @ObservationIgnored private unowned let host: SpotsHost
    @ObservationIgnored private let clock: RunClock
    @ObservationIgnored private var count = 0
    @ObservationIgnored private var leaving: Set<Int> = []
    @ObservationIgnored private var ends: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var isHeld = false
    @ObservationIgnored private var fixHolder: Int?

    public init(host: SpotsHost, clock: RunClock = RunClock()) {
        self.host = host
        self.clock = clock
    }

    public func add(_ note: ToastNote, kind: ToastKind, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = Toasts.duration) {
        let existing = note.id.flatMap { id in stacked.first { $0.note.id == id && $0.spot == spot } }
        let number = existing?.id ?? next()
        let fixKey = press == nil ? nil : key
        let held = fixKey.flatMap { holdFixKey(number, key: $0) }
        let words = held.map { "\(note.words) Press `\($0.label)` to fix it." } ?? note.words
        let toast = existing ?? Toast(id: number, spot: spot, note: note, words: words, kind: kind)
        existing?.take(note, words: words, kind: kind)
        toast.duration = note.keeps || kind == .work ? nil : duration
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
                guard let self, isStacked(number) else { return }
                toast.isShown = true
                takeLead()
            }
        }
        ends.removeValue(forKey: number)?.cancel()
        if !isHeld { end(toast) }
    }

    public func drop(_ id: String, of spot: String) {
        stacked.first { $0.note.id == id && $0.spot == spot }.map { leave($0.id) }
    }

    public func press(_ number: Int) {
        shown.first { $0.id == number }?.press?()
        leave(number)
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

    private func isStacked(_ number: Int) -> Bool {
        shown.contains { $0.id == number } && !leaving.contains(number)
    }

    private func next() -> Int {
        count += 1
        return count
    }

    private func dropped(by toast: Toast) -> [Int] {
        let stacked = stacked
        let giving = stacked.filter { $0.spot == toast.spot && $0.kind == .work }.map(\.id)
        let staying = stacked.filter { !giving.contains($0.id) }
        return giving + staying.dropFirst(Self.limit - 1).map(\.id)
    }

    private func leave(_ number: Int) {
        ends.removeValue(forKey: number)?.cancel()
        guard let toast = shown.first(where: { $0.id == number }), leaving.insert(number).inserted else { return }
        if toast.isShown { toast.isShown = false }
        takeLead()
        if fixHolder == number { passFixKey() }
        after(MotionTokens.fadeOut) { [weak self] in
            guard let self else { return }
            leaving.remove(number)
            host.change(.move, {
                shown.removeAll { $0.id == number }
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
        let number = toast.id
        ends[number]?.cancel()
        ends[number] = after(duration) { [weak self] in self?.leave(number) }
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
    private func holdFixKey(_ number: Int, key: Shortcut) -> Shortcut? {
        window?.dropFixKey()
        fixHolder = nil
        guard window?.holdFixKey(key, press: { [weak self] in self?.press(number) }) == true else { return nil }
        fixHolder = number
        return key
    }

    private func passFixKey() {
        window?.dropFixKey()
        fixHolder = nil
        guard let next = stacked.first(where: { $0.fixKey != nil }), let key = next.fixKey else { return }
        holdFixKey(next.id, key: key)
    }

    private func takeLead() {
        let next = shown.first { $0.isShown }?.kind
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
