import Foundation

/// What the person picks in the overlay of a source with no value (S3): a drag picks an area, a click picks the front window
/// under the pointer, and a click where no window is picks the display. A kind of source allows only its own picks.
/// Each frame is in points from the top left of the main display, and the windows come front first.
public struct ScreenPick: Sendable {
    public struct Item: Equatable, Sendable {
        public let id: UInt32
        public let frame: CGRect

        public init(id: UInt32, frame: CGRect) {
            self.id = id
            self.frame = frame
        }
    }

    private enum Kind {
        case any
        case display
        case window
        case area
    }

    /// The distance in points that makes a press a drag.
    private static let dragLength: CGFloat = 4

    private let kind: Kind
    private let displays: [Item]
    private let windows: [Item]

    /// Returns nil for a source that has its value, which needs no pick.
    public init?(source: ScreenSource, displays: [Item], windows: [Item]) {
        switch source {
        case .any: kind = .any
        case .display(nil): kind = .display
        case .window(nil): kind = .window
        case .area(nil): kind = .area
        default: return nil
        }
        self.displays = displays
        self.windows = windows
    }

    /// The frame to light under the pointer: its window, or its display.
    public func hover(at point: CGPoint) -> CGRect? {
        switch kind {
        case .any: (window(at: point) ?? display(at: point))?.frame
        case .window: window(at: point)?.frame
        case .display: display(at: point)?.frame
        case .area: nil
        }
    }

    /// The area of a drag so far, on the display where it started, or nil when it is not a drag of an area.
    public func area(from start: CGPoint, to end: CGPoint) -> CGRect? {
        guard kind == .any || kind == .area, hypot(end.x - start.x, end.y - start.y) >= Self.dragLength,
              let display = display(at: start) else { return nil }
        let low = CGPoint(x: min(start.x, end.x).rounded(), y: min(start.y, end.y).rounded())
        let high = CGPoint(x: max(start.x, end.x).rounded(), y: max(start.y, end.y).rounded())
        return CGRect(x: low.x, y: low.y, width: high.x - low.x, height: high.y - low.y).intersection(display.frame)
    }

    /// The pick of a press and its release, or nil when they pick nothing and the overlay stays.
    public func target(from start: CGPoint, to end: CGPoint) -> ScreenTarget? {
        if hypot(end.x - start.x, end.y - start.y) >= Self.dragLength {
            return area(from: start, to: end).map { .area($0) }
        }
        switch kind {
        case .any: return window(at: end).map { .window($0.id) } ?? display(at: end).map { .display($0.id) }
        case .window: return window(at: end).map { .window($0.id) }
        case .display: return display(at: end).map { .display($0.id) }
        case .area: return nil
        }
    }

    private func window(at point: CGPoint) -> Item? {
        windows.first { $0.frame.contains(point) }
    }

    private func display(at point: CGPoint) -> Item? {
        displays.first { $0.frame.contains(point) }
    }
}
