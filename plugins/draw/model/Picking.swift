import Foundation

/// The boards picked in the list, as Finder picks files: a click picks one, a Command-click adds or drops one, a
/// Shift-click picks the run from the anchor, and the arrows move the focus, or grow the run with Shift.
struct Picking: Equatable {
    enum Mode {
        case only, toggle, range
    }

    private(set) var picked: Set<URL> = []
    /// The board that a run starts from.
    private(set) var anchor: URL?
    /// The board that the arrows move from.
    private(set) var focus: URL?

    mutating func click(_ item: URL, in order: [URL], mode: Mode) {
        switch mode {
        case .only:
            picked = [item]
            anchor = item
        case .toggle:
            if picked.contains(item) { picked.remove(item) } else { picked.insert(item) }
            anchor = item
        case .range:
            picked = run(from: anchor ?? item, to: item, in: order)
        }
        focus = item
    }

    /// Moves the focus by `offset` places, and picks it alone, or the run from the anchor to it. Returns the new focus.
    @discardableResult
    mutating func step(_ offset: Int, in order: [URL], extend: Bool) -> URL? {
        guard !order.isEmpty else { return nil }
        let index = focus.flatMap { order.firstIndex(of: $0) } ?? (offset > 0 ? -1 : order.count)
        let next = order[min(order.count - 1, max(0, index + offset))]
        if extend {
            picked = run(from: anchor ?? next, to: next, in: order)
            focus = next
        } else {
            click(next, in: order, mode: .only)
        }
        return next
    }

    /// Picks only this board, such as the one a tab shows.
    mutating func reset(to item: URL) {
        picked = [item]
        anchor = item
        focus = item
    }

    private func run(from start: URL, to end: URL, in order: [URL]) -> Set<URL> {
        guard let first = order.firstIndex(of: start), let last = order.firstIndex(of: end) else { return [end] }
        return Set(order[min(first, last)...max(first, last)])
    }
}
