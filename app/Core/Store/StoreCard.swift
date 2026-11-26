import Foundation

public struct StoreCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let spot: Spot
    public let mark: StoreMark?
    let words: String

    init(id: String, spot: Spot, mark: StoreMark?) {
        self.id = id
        self.spot = spot
        self.mark = mark
        words = ([spot.name, spot.subtitle ?? ""] + spot.keywords).joined(separator: " ").folded
    }
}
