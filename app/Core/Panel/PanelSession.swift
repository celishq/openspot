import Foundation

public struct PanelSession: Equatable, Sendable {
    public static let restoreTime: TimeInterval = 90

    public struct Parked: Equatable, Sendable {
        public let flow: Flow
        public let sheetQuery: String
        public let at: Date
    }

    var ends = false
    var isEnded = false
    var parked: Parked?

    mutating func hide(flow: Flow, sheetQuery: String, at now: Date) {
        isEnded = ends
        ends = false
        parked = isEnded ? nil : Parked(flow: flow, sheetQuery: sheetQuery, at: now)
    }

    func startsClean(at now: Date, within restoreTime: TimeInterval = Self.restoreTime) -> Bool {
        isEnded || parked.map { now.timeIntervalSince($0.at) > restoreTime } == true
    }
}
