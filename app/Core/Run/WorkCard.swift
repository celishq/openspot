import Foundation

public struct WorkCard: Equatable, Sendable {
    public let spot: String
    public let words: String
    public let fill: WorkFill

    public init(spot: String, words: String, fill: WorkFill) {
        self.spot = spot
        self.words = words
        self.fill = fill
    }
}
