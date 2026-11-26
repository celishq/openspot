import Foundation

public struct StorePreview: Equatable, Sendable {
    public let face: ViewTree
    public let size: SpotSize

    public init(face: ViewTree, spot: Spot) {
        self.face = face
        size = ([spot.size] + SpotSize.all).first(where: face.draws) ?? .strip
    }

    init(of spot: Spot) {
        let text = try? String(contentsOf: SpotSample.text(beside: spot.url), encoding: .utf8)
        self.init(face: text.map { Frame(text: $0, kinds: spot.kinds).face } ?? .empty, spot: spot)
    }
}
