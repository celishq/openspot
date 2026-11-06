import Foundation

/// What the panel says while a person drags `.spot` files over it. It reads the first file, and runs nothing.
public struct SpotDrop: Equatable, Sendable {
    public let symbol: String
    public let title: String
    public let detail: String?

    /// Reads dragged files for a plugins folder. A file that cannot be installed says why, before the drop.
    public init(paths: [String], folder: URL) {
        let url = URL(fileURLWithPath: paths.first ?? "")
        do {
            let review = try SpotReview(spot: SharedSpot(contentsOf: url), folder: folder)
            symbol = review.symbol
            title = "Drop to install \(review.name)"
            detail = paths.count > 1 ? "Openspot installs one spot at a time" : review.description
        } catch {
            symbol = "exclamationmark.triangle"
            title = "Cannot install \(url.deletingPathExtension().lastPathComponent)"
            detail = (error as? PluginError)?.reason ?? "Openspot cannot read this file."
        }
    }
}
