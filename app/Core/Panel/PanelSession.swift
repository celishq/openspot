import Foundation

public struct PanelSession: Equatable, Sendable {
    public static let restoreTime: TimeInterval = 90
    public static let lookTime: TimeInterval = 2

    public struct Parked: Equatable, Sendable {
        public let at: Date
    }

    public struct Visit: Equatable, Sendable {
        var place: SessionTrail.Place
        let since: Date
        var ran = false
        var isRestored = false

        func isWorthKeeping(at now: Date) -> Bool {
            ran || (!isRestored && place.start != nil && now.timeIntervalSince(since) >= PanelSession.lookTime)
        }
    }

    var ends = false
    var isEnded = false
    var parked: Parked?
    var visit: Visit?

    mutating func hide(at now: Date) {
        isEnded = ends
        ends = false
        parked = isEnded ? nil : Parked(at: now)
    }

    func startsClean(at now: Date, within restoreTime: TimeInterval = Self.restoreTime) -> Bool {
        isEnded || parked.map { now.timeIntervalSince($0.at) > restoreTime } == true
    }
}
