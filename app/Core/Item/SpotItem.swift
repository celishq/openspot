import Foundation

public struct SpotItem: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    public let picture: Icon?
    public let place: String?
    public let hides: [String]?
    public let keywords: [String]
    public let shortcut: String?
    public let records: Bool
    public let takesShake: Bool
    public let isOn: Bool
    public let isToggle: Bool
    public let tone: MetricValue.Tone?
    public let file: String?
    public let fields: [TextBlock.Field]
    public let card: SpotState?
    public let pin: Pin?

    public enum Pin: String, Sendable {
        case top, bottom
    }

    public var isPinned: Bool {
        pin != nil
    }
    public let openTitle: String?
    public let staysOnPick: Bool
    public let form: CommandAction?
    public let move: FlowMove?
    public let section: String?
    public let number: NumberReading?
    public let look: SpotPart.Look?

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, place: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, records: Bool = false, takesShake: Bool = false, isOn: Bool = false, isToggle: Bool = false, tone: MetricValue.Tone? = nil, file: String? = nil, fields: [TextBlock.Field] = [], card: SpotState? = nil, pin: Pin? = nil, openTitle: String? = nil, staysOnPick: Bool = false, form: CommandAction? = nil, move: FlowMove? = nil, section: String? = nil, number: NumberReading? = nil, look: SpotPart.Look? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.picture = picture
        self.place = place
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
        self.staysOnPick = staysOnPick
        self.form = form
        self.move = move
        self.section = section
        self.number = number
        self.look = look
    }

    init?(block: TextBlock, kind: BlockKind, section: String?) {
        guard let run = block.value(kind.word) else { return nil }
        let hides = block.values(ItemKey.hides)
        let records = kind == .hotkey
        let number = kind == .number || kind == .series ? NumberReading(block: block) : nil
        self.init(
            title: block.value(ItemKey.title) ?? run,
            subtitle: block.value(ItemKey.detail),
            run: run,
            picture: Icon(text: block.value(ItemKey.icon)),
            place: block.value(ItemKey.place),
            hides: hides.isEmpty ? nil : hides,
            keywords: block.list(ItemKey.keywords),
            shortcut: records ? block.value(ItemKey.value) ?? Trigger.unset : nil,
            records: records,
            takesShake: records && block.flag(ItemKey.shake) == true,
            isOn: !records && block.flag(ItemKey.value) == true,
            isToggle: kind == .toggle,
            tone: block.value(ItemKey.tone).flatMap(MetricValue.Tone.init),
            file: block.value(ItemKey.file).flatMap { $0.hasPrefix("/") ? $0 : nil },
            fields: Self.fields(of: block),
            pin: block.value(ItemKey.pin).flatMap(Pin.init(rawValue:)),
            openTitle: block.value(ItemKey.openTitle),
            staysOnPick: block.flag(ItemKey.close) == false,
            form: block.flag(ItemKey.form) == true ? CommandAction(id: Frame.open, title: block.value(ItemKey.openTitle) ?? block.value(ItemKey.title) ?? run, after: block.flag(ItemKey.close) == false ? .stay : .close, isForm: true) : nil,
            move: FlowMove(item: block),
            section: section,
            number: number,
            look: SpotPart.Look(style: StyleCache.shared.style(of: block.value(ViewNode.classKey) ?? "").resolved(for: [.sheet]))
        )
    }

    private static func fields(of block: TextBlock) -> [TextBlock.Field] {
        guard block.fields.dropFirst().contains(where: { ItemKey(rawValue: $0.key) == nil && !BlockKind.commonKeys.contains($0.key) && $0.key != Self.type }) else { return [] }
        return block.fields.filter { $0.key != ViewNode.parentKey && $0.key != ViewNode.classKey }
    }

    private static let type = "type"

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
        [spot.name, place].compactMap { $0 }.joined(separator: " › ")
    }

    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? iconFile.map(FileIcon.init(path:))
    }
}
