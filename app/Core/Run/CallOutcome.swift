import Foundation

struct CallOutcome: Equatable, Sendable {
    var seconds: TimeInterval
    var answered: TimeInterval?
    var failure: SpotUsage.Failure?
    var reason: String?
}
