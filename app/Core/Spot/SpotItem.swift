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
    /// The name of the place inside its spot that it sits under, such as the pane of a section.
    public let parent: String?
    public let hides: [String]?
    /// Words that find this row in a search, though it does not show them.
    public let keywords: [String]
    /// The key this row shows. A pick records the next key that the person presses.
    public let shortcut: String?
    /// Whether this row shows that its thing is on.
    public let isOn: Bool
    /// The dot on its picture, such as `on` for a thing that is active.
    public let tone: MetricValue.Tone?
    /// The template that draws it, from `as`.
    public let template: String?
    /// Each line of its block that is not one of its own keys, from which the slots of a template take their values.
    public let fields: [TextBlock.Field]

    /// The keys that a row reads itself, which are the slots of the default template (U14).
    public static let ownKeys: Set<String> = [
        "row", "title", "detail", "icon", "parent", "hides", "keyword", "shortcut", "on", "tone", "as"
    ]

    public init(title: String, subtitle: String? = nil, run: String, symbol: String? = nil, file: String? = nil, image: String? = nil, glyph: String? = nil, parent: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, isOn: Bool = false, tone: MetricValue.Tone? = nil, template: String? = nil, fields: [TextBlock.Field] = []) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.symbol = symbol
        self.file = file
        self.image = image
        self.glyph = glyph
        self.parent = parent
        self.hides = hides
        self.keywords = keywords
        self.shortcut = shortcut
        self.isOn = isOn
        self.tone = tone
        self.template = template
        self.fields = fields
    }

    /// Reads the block of one row: `row=<id>`, which a pick sends, and `title`, which is the id when it has none.
    public init?(block: TextBlock) {
        guard let run = block.value("row") else { return nil }
        let title = block.value("title") ?? run
        let hides = block.values("hides")
        let icon = Icon(text: block.value("icon"))
        self.init(
            title: title,
            subtitle: block.value("detail"),
            run: run,
            symbol: icon?.symbol,
            file: icon?.file,
            image: icon?.image,
            glyph: icon?.glyph,
            parent: block.value("parent"),
            hides: hides.isEmpty ? nil : hides,
            keywords: block.values("keyword"),
            shortcut: block.value("shortcut"),
            isOn: block.flag("on") ?? false,
            tone: block.value("tone").flatMap(MetricValue.Tone.init),
            template: block.value("as"),
            fields: block.fields.filter { !Self.ownKeys.contains($0.key) }
        )
    }

    /// The value that it gives a slot with `<slot>=<value>`.
    public func value(of slot: String) -> String? {
        fields.last { $0.key == slot && !$0.value.isEmpty }?.value
    }

    /// The other keys that it gives a slot with `<slot>.<key>=<value>`.
    public func keys(of slot: String) -> [TextBlock.Field] {
        fields.compactMap { field in
            field.key.hasPrefix(slot + ".") ? .init(key: String(field.key.dropFirst(slot.count + 1)), value: field.value) : nil
        }
    }

    /// The `icon` value of its picture.
    public var iconText: String? {
        symbol ?? file ?? image ?? glyph
    }

    /// Where it lives: the name of its spot, then its parent.
    public func path(in spot: Spot) -> String {
        [spot.name, parent].compactMap { $0 }.joined(separator: " › ")
    }

    /// The picture a row draws: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }
}
