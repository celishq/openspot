import Foundation

/// One thing a list offers. Its `run` value goes back to the command when it is picked.
public struct SpotItem: Equatable, Decodable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    public let symbol: String?
    public let file: String?
    public let image: String?
    public let hides: [String]?

    public init(title: String, subtitle: String? = nil, run: String, symbol: String? = nil, file: String? = nil, image: String? = nil, hides: [String]? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.symbol = symbol
        self.file = file
        self.image = image
        self.hides = hides
    }

    /// The picture a row draws: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }
}
