import Foundation

public struct FlowSwipe: Sendable {
    public enum Phase: Sendable {
        case began, changed, ended
    }

    public enum Step: Equatable, Sendable {
        case back, forward
    }

    private var distance = 0.0
    private var isScroll = false
    private var hasStepped = false

    public init() {}

    public mutating func take(dx: Double, dy: Double, phase: Phase) -> Step? {
        switch phase {
        case .began:
            distance = dx
            isScroll = abs(dy) > abs(dx)
            hasStepped = false
            return nil
        case .ended:
            distance = 0
            return nil
        case .changed:
            guard !isScroll, !hasStepped else { return nil }
            distance += dx
            guard abs(distance) >= Double(SpotTokens.swipeDistance) else { return nil }
            hasStepped = true
            return distance > 0 ? .back : .forward
        }
    }
}
