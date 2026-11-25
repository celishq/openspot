import Foundation

public enum StoreAsk: Equatable, Sendable {
    case clash(StoreReview)
    case install(StoreReview)
    case update(StoreChange)
    case revert(StoreChange)
}
