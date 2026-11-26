import Foundation

public struct StoreCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let spot: Spot
    public let mark: StoreMark?
    public let preview: StorePreview?
    let words: String

    init(id: String, spot: Spot, mark: StoreMark?, preview: StorePreview? = nil) {
        self.id = id
        self.spot = spot
        self.mark = mark
        self.preview = preview
        words = ([spot.name, spot.subtitle ?? ""] + spot.keywords).joined(separator: " ").folded
    }
}
