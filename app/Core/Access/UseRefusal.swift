import Foundation

public struct UseRefusal: Error, Equatable, Sendable {
    public let spot: String
    public let title: String
    public let use: SpotUse
    public let call: String
    let words: String

    init(spot: Spot, call: SpotUseCall) {
        self.spot = spot.id
        title = spot.name
        use = call.use
        self.call = call.name
        words = call.words
    }

    public var lines: String {
        """
        Openspot stopped \(title), because it \(words) without `\(use.rawValue)` in the `uses` of its spot.toml.
        Add it there, or run `openspot spot allow \(spot) \(use.rawValue)`.

        """
    }

    public var toast: String {
        "Openspot stopped \(title) from using `\(use.rawValue)`, which its spot.toml does not name."
    }
}
