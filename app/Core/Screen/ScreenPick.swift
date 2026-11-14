import Foundation

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

    private static let dragLength: CGFloat = 4

    private let kind: Kind
    private let displays: [Item]
    private let windows: [Item]

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

    public func hover(at point: CGPoint) -> CGRect? {
        switch kind {
        case .any: (window(at: point) ?? display(at: point))?.frame
        case .window: window(at: point)?.frame
        case .display: display(at: point)?.frame
        case .area: nil
        }
    }

    public func area(from start: CGPoint, to end: CGPoint) -> CGRect? {
        guard kind == .any || kind == .area, hypot(end.x - start.x, end.y - start.y) >= Self.dragLength,
              let display = display(at: start) else { return nil }
        let low = CGPoint(x: min(start.x, end.x).rounded(), y: min(start.y, end.y).rounded())
        let high = CGPoint(x: max(start.x, end.x).rounded(), y: max(start.y, end.y).rounded())
        return CGRect(x: low.x, y: low.y, width: high.x - low.x, height: high.y - low.y).intersection(display.frame)
    }

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
