import Foundation

/// Finds a shake in the moves of the pointer: quick turns left and right, each after a long enough way, close in time (W2).
/// One shake fires once, and a shake that goes on fires again only after a rest.
public struct PointerShake: Sendable {
    /// The turns that make a shake.
    static let turns = 4
    /// The least way in points between two turns.
    static let leg: CGFloat = 40
    /// The most seconds that the turns of one shake take.
    static let span: TimeInterval = 0.8
    /// The seconds after a shake in which no shake fires.
    static let rest: TimeInterval = 1
    /// The way back in points that counts as a turn, so that a tremble of the hand is no turn.
    private static let slack: CGFloat = 8

    private var start: CGFloat?
    private var peak: CGFloat = 0
    private var direction: CGFloat = 0
    private var times: [TimeInterval] = []
    private var fired = -TimeInterval.infinity

    public init() {}

    /// Takes the place of the pointer across the screen at a time in seconds, and returns true when it ends a shake.
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
        if abs(peak - start) >= Self.leg {
            times.append(time)
        } else {
            times = []
        }
        self.start = peak
        peak = x
        direction = -direction
        times.removeAll { time - $0 > Self.span }
        guard times.count >= Self.turns, time - fired >= Self.rest else { return false }
        times = []
        fired = time
        return true
    }
}
