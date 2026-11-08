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
    /// Words that find this row in a search, though it does not show them.
    public let keywords: [String]
    /// The key this row shows. A pick records the next key that the person presses.
    public let shortcut: String?
    /// Whether this row shows that its thing is on.
    public let isOn: Bool

    public init(title: String, subtitle: String? = nil, run: String, symbol: String? = nil, file: String? = nil, image: String? = nil, glyph: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, isOn: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.symbol = symbol
        self.file = file
        self.image = image
        self.glyph = glyph
        self.hides = hides
        self.keywords = keywords
        self.shortcut = shortcut
        self.isOn = isOn
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
            hides: hides.isEmpty ? nil : hides,
            keywords: block.values("keyword"),
            shortcut: block.value("shortcut"),
            isOn: block.flag("on") ?? false
        )
    }

    /// The picture a row draws: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }
}
