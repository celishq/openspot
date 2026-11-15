import Foundation

public struct SpotDrop: Equatable, Sendable {
    public let symbol: String
    public let title: String
    public let detail: String?

    public init(reviewing review: ReviewSpot) {
        symbol = review.symbol
        title = review.name
        detail = review.subtitle
    }

    public init(paths: [String], folder: URL) {
        let url = URL(fileURLWithPath: paths.first ?? "")
        do {
            let review = try ReviewSpot(spot: SpotPackage(contentsOf: url), folder: folder)
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
