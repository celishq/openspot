import Foundation

public enum HostSheet: Equatable, Sendable {
    case review(ReviewSpot)
    case fault(FaultSpot)
    case account(AccountSheet)

    func answer(_ arguments: [String], input: String?, variables: [String: String]) async throws -> String {
        switch self {
        case .review(let review): arguments.first == ReviewSpot.installPart ? try await review.add() : try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments)
        case .account(let account): try await account.answer(arguments, input: input, variables: variables)
        }
    }
}
