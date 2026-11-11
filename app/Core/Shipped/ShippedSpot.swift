import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case review(ReviewSpot)
    /// The sheet of a file that does not load.
    case fault(FaultSpot)

    /// The ID of the plugin that holds the cards of the files that do not load.
    public static let faultsID = "openspot/faults"

    /// The ID of the sheet that shows a shared spot, which has no card in the grid.
    public static let installID = "openspot/install"

    /// The sheet that shows a shared spot before a person installs it.
    public static func command(reviewing review: ReviewSpot) -> Spot {
        Spot(
            id: installID,
            name: review.name,
            url: review.folder,
            kind: .list,
            symbol: review.symbol,
            subtitle: review.subtitle,
            read: .sheet,
            order: .max,
            shipped: .review(review)
        )
    }

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        switch self {
        case .review(let review): try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments)
        }
    }
}
