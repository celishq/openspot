import Foundation

struct CallOutcome: Equatable, Sendable {
    var seconds: TimeInterval
    var answered: TimeInterval?
    var failure: StatsLog.Failure?
    var reason: String?
}
