import Foundation

public struct StoreCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let spot: Spot
    public let mark: StoreMark?
    public let preview: StorePreview

    init(id: String, spot: Spot, mark: StoreMark?) {
        self.id = id
        self.spot = spot
        self.mark = mark
        preview = StorePreview(of: spot)
    }
}
