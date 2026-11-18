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
    public let isToggle: Bool
    public let tone: MetricValue.Tone?
    public let file: String?
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
    public let bars: [Double?]
    public let section: String?

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, parent: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, records: Bool = false, takesShake: Bool = false, isOn: Bool = false, isToggle: Bool = false, tone: MetricValue.Tone? = nil, file: String? = nil, fields: String? = nil, card: SpotState? = nil, pin: Pin? = nil, openTitle: String? = nil, staysOnPick: Bool = false, focusSubtitle: String? = nil, move: FlowMove? = nil, bars: [Double?] = [], section: String? = nil) {
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
        self.isToggle = isToggle
        self.tone = tone
        self.file = file
        self.fields = fields
        self.card = card
        self.pin = pin
        self.openTitle = openTitle
        self.focusSubtitle = focusSubtitle
        self.staysOnPick = staysOnPick
        self.move = move
        self.bars = bars
        self.section = section
    }

    public init?(block: TextBlock) {
        guard let run = block.value(RowKey.row) else { return nil }
        let title = block.value(RowKey.title) ?? run
        let hides = block.values(RowKey.hides)
        self.init(
            title: title,
            subtitle: block.value(RowKey.detail),
            run: run,
            picture: Icon(text: block.value(RowKey.icon)),
            parent: block.value(RowKey.parent),
            hides: hides.isEmpty ? nil : hides,
            keywords: block.list(RowKey.keywords),
            shortcut: block.value(RowKey.shortcut),
            records: block.value(RowKey.type) == RowKey.hotkey,
            takesShake: block.flag(RowKey.shake) ?? false,
            isOn: block.flag(RowKey.value) ?? false,
            isToggle: block.value(RowKey.type) == RowKey.toggle,
            tone: block.value(RowKey.tone).flatMap(MetricValue.Tone.init),
            file: block.value(RowKey.file).flatMap { $0.hasPrefix("/") ? $0 : nil },
            fields: Self.fields(of: block),
            pin: block.value(RowKey.pin).flatMap(Pin.init(rawValue:)),
            openTitle: block.value(RowKey.open),
            staysOnPick: block.flag(RowKey.close) == false,
            focusSubtitle: block.value(RowKey.focus),
            move: FlowMove(item: block),
            bars: Self.bars(values: block.values(RowKey.value), max: block.value(RowKey.max).flatMap(Double.init)),
            section: block.value(RowKey.section)
        )
    }

    private static func fields(of block: TextBlock) -> String? {
        guard block.fields.contains(where: { RowKey(rawValue: $0.key) == nil }) else { return nil }
        return TextBlock(fields: block.fields.map { .init(key: "item.\($0.key)", value: $0.value) }).text
    }

    private static func bars(values: [String], max: Double?) -> [Double?] {
        guard values.count > 1 else { return [] }
        let numbers = values.map { Double($0).flatMap { $0.isFinite ? $0 : nil } }
        let top = max ?? numbers.compactMap { $0 }.max() ?? 0
        return numbers.map { number in number.map { top > 0 ? Swift.min(Swift.max($0 / top, 0), 1) : 0 } }
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

    public func path(in spot: Spot) -> String {
        [spot.name, parent].compactMap { $0 }.joined(separator: " › ")
    }

    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? iconFile.map(FileIcon.init(path:))
    }
}
