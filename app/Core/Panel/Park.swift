import Foundation

public struct Park: Equatable, Sendable {
    public static let restoreTime: TimeInterval = 90

    public enum State: Equatable, Sendable {
        case shown
        case parked(Date)
        case ended
    }

    var state = State.shown

    var isParked: Bool {
        if case .parked = state { true } else { false }
    }

    mutating func hide(at now: Date) {
        if state != .ended { state = .parked(now) }
    }

    func startsClean(at now: Date, within restoreTime: TimeInterval = Self.restoreTime) -> Bool {
        switch state {
        case .shown: false
        case .parked(let at): now.timeIntervalSince(at) > restoreTime
        case .ended: true
        }
    }
}
