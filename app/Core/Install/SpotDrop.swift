import Foundation

/// What the panel says while a person drags `.spot` files over it. It reads the first file, and runs nothing.
public struct SpotDrop: Equatable, Sendable {
    public let symbol: String
    public let title: String
    public let detail: String?

    /// Says what the header of a review says, for a review that starts with no drag.
    public init(reviewing review: ReviewSpot) {
        symbol = review.symbol
        title = review.name
        detail = review.subtitle
    }

    /// Reads dragged files for a spots folder. A file that cannot be installed says why, before the drop.
    public init(paths: [String], folder: URL) {
        let url = URL(fileURLWithPath: paths.first ?? "")
        do {
            let review = try ReviewSpot(spot: SharedSpot(contentsOf: url), folder: folder)
            symbol = review.symbol
            title = review.name
            detail = paths.count > 1 ? "Openspot installs one spot at a time" : "Drop to install"
        } catch {
            symbol = "exclamationmark.triangle"
            title = "Cannot install \(url.deletingPathExtension().lastPathComponent)"
            detail = (error as? SpotError)?.reason ?? "Openspot cannot read this file."
        }
    }
}
