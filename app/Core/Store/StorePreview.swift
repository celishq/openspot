import Foundation

public struct StorePreview: Equatable, Sendable {
    public let face: ViewTree
    public let size: SpotSize

    init?(of spot: Spot) {
        guard let text = try? String(contentsOf: SpotSample.text(beside: spot.url), encoding: .utf8) else { return nil }
        let face = Frame(text: text, kinds: spot.kinds).face
        guard let size = ([spot.size] + SpotSize.all).first(where: face.draws) else { return nil }
        self.face = face
        self.size = size
    }
}
