import Foundation

public struct Session: Equatable, Sendable {
    public static let lookTime: TimeInterval = 2

    var place: SessionPlace
    let since: Date
    var ran = false
    var isRestored = false

    func isWorthKeeping(at now: Date) -> Bool {
        ran || (!isRestored && place.start != nil && now.timeIntervalSince(since) >= Self.lookTime)
    }
}
