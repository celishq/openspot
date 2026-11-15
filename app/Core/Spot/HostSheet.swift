import Foundation

public enum HostSheet: Equatable, Sendable {
    case review(ReviewSpot)
    case fault(FaultSpot)

    func answer(_ arguments: [String], input: String?, variables: [String: String], base: [String: String]? = nil) async throws -> String {
        switch self {
        case .review(let review): arguments.first == ReviewSpot.installPart ? try await review.add() : try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments, base: base)
        }
    }
}
