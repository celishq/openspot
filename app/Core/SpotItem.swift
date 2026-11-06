import Foundation

/// One thing a list offers. Its `run` value goes back to the command when it is picked.
public struct SpotItem: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    public let symbol: String?
    public let file: String?
    public let image: String?
    public let glyph: String?
    public let hides: [String]?

    public init(title: String, subtitle: String? = nil, run: String, symbol: String? = nil, file: String? = nil, image: String? = nil, glyph: String? = nil, hides: [String]? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.symbol = symbol
        self.file = file
        self.image = image
        self.glyph = glyph
        self.hides = hides
    }

    /// Reads the block of one row. It needs a run value.
    public init?(block: TextBlock) {
        guard let title = block.value("row"), let run = block.value("run") else { return nil }
        let hides = block.values("hides")
        self.init(
            title: title,
            subtitle: block.value("detail"),
            run: run,
            symbol: block.value("symbol"),
            file: block.value("file"),
            image: block.value("image"),
            glyph: block.value("glyph"),
            hides: hides.isEmpty ? nil : hides
        )
    }

    /// The picture a row draws: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }
}
