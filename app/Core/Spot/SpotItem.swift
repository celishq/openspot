import Foundation

/// One thing a list offers. Its `run` value goes back to the command when it is picked.
public struct SpotItem: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    /// The picture that its `icon` value names.
    public let picture: Icon?
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
    /// The file that the row stands for, which a drag takes out of the sheet (O1).
    public let file: String?

    /// The keys that a row reads itself, which are the slots of the default template (U14).
    public static let ownKeys: Set<String> = [
        "row", "title", "detail", "icon", "parent", "hides", "keyword", "shortcut", "on", "tone", "as", "file"
    ]

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, parent: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, isOn: Bool = false, tone: MetricValue.Tone? = nil, template: String? = nil, fields: [TextBlock.Field] = [], file: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.picture = picture
        self.parent = parent
        self.hides = hides
        self.keywords = keywords
        self.shortcut = shortcut
        self.isOn = isOn
        self.tone = tone
        self.template = template
        self.fields = fields
        self.file = file
    }

    /// Reads the block of one row: `row=<id>`, which a pick sends, and `title`, which is the id when it has none.
    public init?(block: TextBlock) {
        guard let run = block.value("row") else { return nil }
        let title = block.value("title") ?? run
        let hides = block.values("hides")
        self.init(
            title: title,
            subtitle: block.value("detail"),
            run: run,
            picture: Icon(text: block.value("icon")),
            parent: block.value("parent"),
            hides: hides.isEmpty ? nil : hides,
            keywords: block.values("keyword"),
            shortcut: block.value("shortcut"),
            isOn: block.flag("on") ?? false,
            tone: block.value("tone").flatMap(MetricValue.Tone.init),
            template: block.value("as"),
            fields: block.fields.filter { !Self.ownKeys.contains($0.key) },
            file: block.value("file").flatMap { $0.hasPrefix("/") ? $0 : nil }
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

    /// The SF Symbol of its picture.
    public var symbol: String? {
        picture?.symbol
    }

    /// The file whose Finder icon the row draws.
    public var iconFile: String? {
        picture?.file
    }

    /// The picture file that the row draws.
    public var image: String? {
        picture?.image
    }

    /// The text, such as an emoji, that the row draws as its picture.
    public var glyph: String? {
        picture?.glyph
    }

    /// The `icon` value of its picture.
    public var iconText: String? {
        symbol ?? iconFile ?? image ?? glyph
    }

    /// Where it lives: the name of its spot, then its parent.
    public func path(in spot: Spot) -> String {
        [spot.name, parent].compactMap { $0 }.joined(separator: " › ")
    }

    /// The picture a row draws: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? iconFile.map(FileIcon.init(path:))
    }
}
