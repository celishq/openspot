import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class Toasts {
    public static let limit = 3
    public static let duration: TimeInterval = 5

    public private(set) var shown: [Toast] = []
    public private(set) var leadKind: ToastKind?
    public private(set) var count = 0
    public private(set) var frontHeight: CGFloat = 0
    @ObservationIgnored public private(set) var width: CGFloat = 0
    @ObservationIgnored public private(set) var height: CGFloat = 0
    @ObservationIgnored public weak var window: ToastWindow?
    @ObservationIgnored private unowned let host: SpotsHost
    @ObservationIgnored private let clock: RunClock
    @ObservationIgnored private var lastMade = 0
    @ObservationIgnored private var leaving: Set<ToastID> = []
    @ObservationIgnored private var ends: [ToastID: Task<Void, Never>] = [:]
    @ObservationIgnored private var isHeld = false
    @ObservationIgnored private var fixKeyToast: ToastID?
    @ObservationIgnored private var frontID: ToastID?

    public init(host: SpotsHost, clock: RunClock = RunClock()) {
        self.host = host
        self.clock = clock
    }

    public func add(_ note: ToastNote, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = Toasts.duration) {
        let id = ToastID(spot: spot, name: note.id.map(ToastID.Name.given) ?? .made(nextMade()))
        let existing = stacked.first { $0.id == id }
        if existing == nil, leaving.remove(id) != nil { shown.removeAll { $0.id == id } }
        let fixKey = press == nil ? nil : key
        let isFront = existing == nil || frontID == id
        let held = isFront ? fixKey.flatMap { holdFixKey(id, key: $0) } : nil
        let words = held.map { "\(note.words) Press `\($0.label)` to fix it." } ?? note.words
        let toast = existing ?? Toast(id: id, note: note, words: words)
        existing?.take(note, words: words)
        toast.duration = note.keeps || note.kind == .work ? nil : duration
        toast.press = press
        toast.fixKey = fixKey
        if existing == nil { dropped(by: toast).forEach(leave) }
        toast.size = window?.measure(toast) ?? .zero
        if existing == nil { shown.insert(toast, at: 0) }
        host.change(.move, { fit() }, completion: {})
        window?.place()
        if existing == nil {
            window?.bringToFront()
            window?.nextFrame { [weak self] in self?.showFront() }
        }
        if existing != nil, frontID == id, !isHeld { end(toast) }
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
        } else if let front = stacked.first {
            end(front)
        }
    }

    private var stacked: [Toast] {
        shown.filter { !leaving.contains($0.id) }
    }

    private func isStacked(_ id: ToastID) -> Bool {
        shown.contains { $0.id == id } && !leaving.contains(id)
    }

    private func nextMade() -> Int {
        lastMade += 1
        return lastMade
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
        showFront()
        host.change(.move, { fit() }, completion: {})
        window?.place()
        after(MotionTokens.fadeOut) { [weak self] in
            guard let self, shown.contains(where: { $0 === toast }) else { return }
            leaving.remove(id)
            shown.removeAll { $0.id == id }
            settle()
        }
    }

    private func settle() {
        fit()
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

    private func showFront() {
        let front = stacked.first
        for toast in shown where toast.isShown != (toast === front) {
            toast.isShown = toast === front
        }
        let next = front?.note.kind
        if next != leadKind { leadKind = next }
        guard front?.id != frontID else { return }
        frontID = front?.id
        ends.values.forEach { $0.cancel() }
        ends.removeAll()
        if let front, !isHeld { end(front) }
        if let front, let key = front.fixKey {
            if fixKeyToast != front.id { holdFixKey(front.id, key: key) }
        } else if fixKeyToast != nil {
            window?.dropFixKey()
            fixKeyToast = nil
        }
    }

    private func fit() {
        let stacked = stacked
        if stacked.count != count { count = stacked.count }
        let front = stacked.first?.size.height ?? 0
        if front != frontHeight { frontHeight = front }
        let seen = shown.filter { $0.id == stacked.first?.id || leaving.contains($0.id) }
        width = max(seen.map(\.size.width).max() ?? 0, count > 1 ? SpotTokens.toastBars(count) : 0)
        height = (seen.map(\.size.height).max() ?? 0) + (count > 1 ? SpotTokens.toastBarsGap + SpotTokens.toastBarHeight : 0)
    }
}
