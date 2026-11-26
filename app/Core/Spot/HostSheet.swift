import Foundation

public enum HostSheet: Equatable, Sendable {
    case review(ReviewSpot)
    case fault(FaultSpot)

    func answer(_ arguments: [String], input: String?, base: [String: String]? = nil) async throws -> HostAnswer {
        switch self {
        case .review(let review): HostAnswer(frame: try review.answer(arguments))
        case .fault(let fault): try await fault.answer(arguments, base: base)
        }
    }
}
