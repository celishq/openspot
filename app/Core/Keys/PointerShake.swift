import Foundation

public struct PointerShake: Sendable {
    static let turns = 5
    static let leastLeg: CGFloat = 40
    static let longestSpan: TimeInterval = 0.8
    static let rest: TimeInterval = 1
    private static let slack: CGFloat = 8

    private var start: CGFloat?
    private var peak: CGFloat = 0
    private var direction: CGFloat = 0
    private var times: [TimeInterval] = []
    private var fired = -TimeInterval.infinity

    public init() {}

    public mutating func take(x: CGFloat, at time: TimeInterval) -> Bool {
        guard let start else {
            self.start = x
            peak = x
            return false
        }
        if direction == 0 {
            if abs(x - start) >= Self.slack { direction = x > start ? 1 : -1 }
            peak = x
            return false
        }
        if (x - peak) * direction >= 0 {
            peak = x
            return false
        }
        guard abs(x - peak) >= Self.slack else { return false }
        if abs(peak - start) >= Self.leastLeg {
            times.append(time)
        } else {
            times = []
        }
        self.start = peak
        peak = x
        direction = -direction
        times.removeAll { time - $0 > Self.longestSpan }
        guard times.count >= Self.turns, time - fired >= Self.rest else { return false }
        times = []
        fired = time
        return true
    }
}
