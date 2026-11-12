import Foundation

/// A sheet that the app answers in Swift, as a service of every spot: the card of a file that does not load, and the review
/// of a spot that a person adds or reads.
public enum HostSheet: Equatable, Sendable {
    case review(ReviewSpot)
    case fault(FaultSpot)
    case account(AccountSheet)

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String]) async throws -> String {
        switch self {
        case .review(let review): arguments.first == ReviewSpot.installPart ? try await review.add() : try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments)
        case .account(let sheet): try await sheet.answer(arguments)
        }
    }
}
