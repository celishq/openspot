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
    /// The key this row shows.
    public let shortcut: String?
    /// Whether a pick records the next key that the person presses, from `type=hotkey`.
    public let records: Bool
    /// Whether a shake of the pointer can be its key as well.
    public let takesShake: Bool
    /// Whether this row shows that its thing is on, from its `value`.
    public let isOn: Bool
    /// The colour of the dot on its picture.
    public let tone: MetricValue.Tone?
    /// The file that the row stands for, which a drag takes out of the sheet (protocol: Files out).
    public let file: String?
    /// The ID of the other spot that a pick goes to, as `<spot> open <row id>` (protocol: Rows).
    public let to: String?
    /// The whole block of the row, which a pick sends on stdin to the spot that `to` names. Only such a row keeps it.
    public let fields: String?
    /// The card that an answer draws in place of its row, from the drawing and the blocks of its frame (protocol: Places).
    public let card: SpotState?
    /// Where it stays, above or under the rows that scroll, from `pin=top` or `pin=bottom`. A search keeps it.
    public let pin: Pin?

    public enum Pin: String, Sendable {
        case top, bottom
    }

    public var isPinned: Bool {
        pin != nil
    }
    /// The second line while the row is selected, from `focus=`, in place of its `detail`.
    public let focusSubtitle: String?
    /// The word for Return on this row, from `open=`, in place of the title of the spot's `open` action.
    public let openTitle: String?
    /// Whether the panel stays open after Return on this row, from `close=false`.
    public let staysOnPick: Bool
    /// Whether a pick opens the row as a page of its spot, from `page=true`, in place of `<spot> open <row id>`.
    public let opensPage: Bool

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, parent: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, records: Bool = false, takesShake: Bool = false, isOn: Bool = false, tone: MetricValue.Tone? = nil, file: String? = nil, to: String? = nil, fields: String? = nil, card: SpotState? = nil, pin: Pin? = nil, openTitle: String? = nil, staysOnPick: Bool = false, focusSubtitle: String? = nil, opensPage: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.picture = picture
        self.parent = parent
        self.hides = hides
        self.keywords = keywords
        self.shortcut = shortcut
        self.records = records
        self.takesShake = takesShake
        self.isOn = isOn
        self.tone = tone
        self.file = file
        self.to = to
        self.fields = fields
        self.card = card
        self.pin = pin
        self.openTitle = openTitle
        self.focusSubtitle = focusSubtitle
        self.staysOnPick = staysOnPick
        self.opensPage = opensPage
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
            keywords: block.list("keywords"),
            shortcut: block.value("shortcut"),
            records: block.value("type") == "hotkey",
            takesShake: block.flag("shake") ?? false,
            isOn: block.flag("value") ?? false,
            tone: block.value("tone").flatMap(MetricValue.Tone.init),
            file: block.value("file").flatMap { $0.hasPrefix("/") ? $0 : nil },
            to: block.value("to"),
            fields: block.value("to") == nil ? nil : block.text,
            pin: block.value("pin").flatMap(Pin.init(rawValue:)),
            openTitle: block.value("open"),
            staysOnPick: block.flag("close") == false,
            focusSubtitle: block.value("focus"),
            opensPage: block.flag("page") == true
        )
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
