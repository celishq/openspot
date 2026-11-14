import Foundation

public struct SpotItem: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    public let picture: Icon?
    public let parent: String?
    public let hides: [String]?
    public let keywords: [String]
    public let shortcut: String?
    public let records: Bool
    public let takesShake: Bool
    public let isOn: Bool
    public let tone: MetricValue.Tone?
    public let file: String?
    public var to: String? {
        if case .push(let spot?, _, _, _)? = move { spot } else { nil }
    }
    public let fields: String?
    public let card: SpotState?
    public let pin: Pin?

    public enum Pin: String, Sendable {
        case top, bottom
    }

    public var isPinned: Bool {
        pin != nil
    }
    public let focusSubtitle: String?
    public let openTitle: String?
    public let staysOnPick: Bool
    public let move: FlowMove?

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, parent: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, records: Bool = false, takesShake: Bool = false, isOn: Bool = false, tone: MetricValue.Tone? = nil, file: String? = nil, fields: String? = nil, card: SpotState? = nil, pin: Pin? = nil, openTitle: String? = nil, staysOnPick: Bool = false, focusSubtitle: String? = nil, move: FlowMove? = nil) {
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
        self.fields = fields
        self.card = card
        self.pin = pin
        self.openTitle = openTitle
        self.focusSubtitle = focusSubtitle
        self.staysOnPick = staysOnPick
        self.move = move
    }

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
            fields: block.value("push.spot") == nil ? nil : block.text,
            pin: block.value("pin").flatMap(Pin.init(rawValue:)),
            openTitle: block.value("open"),
            staysOnPick: block.flag("close") == false,
            focusSubtitle: block.value("focus"),
            move: FlowMove(block: block, own: run).flatMap { if case .push = $0 { $0 } else { nil } }
        )
    }

    public var symbol: String? {
        picture?.symbol
    }

    public var iconFile: String? {
        picture?.file
    }

    public var image: String? {
        picture?.image
    }

    public var glyph: String? {
        picture?.glyph
    }

    public var iconText: String? {
        symbol ?? iconFile ?? image ?? glyph
    }

    public func path(in spot: Spot) -> String {
        [spot.name, parent].compactMap { $0 }.joined(separator: " › ")
    }

    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? iconFile.map(FileIcon.init(path:))
    }
}
