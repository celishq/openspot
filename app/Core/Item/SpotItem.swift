import Foundation

public struct SpotItem: Equatable, Sendable {
    private final class Extras: Equatable, Sendable {
        let hides: [String]?
        let shortcut: String?
        let file: String?
        let fields: [TextBlock.Field]
        let card: SpotState?
        let openTitle: String?
        let move: FlowMove?
        let peek: [TextBlock]
        let number: NumberReading?

        init?(hides: [String]?, shortcut: String?, file: String?, fields: [TextBlock.Field], card: SpotState?, openTitle: String?, move: FlowMove?, peek: [TextBlock], number: NumberReading?) {
            guard hides != nil || shortcut != nil || file != nil || !fields.isEmpty || card != nil || openTitle != nil || move != nil || !peek.isEmpty || number != nil else { return nil }
            self.hides = hides
            self.shortcut = shortcut
            self.file = file
            self.fields = fields
            self.card = card
            self.openTitle = openTitle
            self.move = move
            self.peek = peek
            self.number = number
        }

        static func == (left: Extras, right: Extras) -> Bool {
            left === right || left.hides == right.hides && left.shortcut == right.shortcut && left.file == right.file && left.fields == right.fields
                && left.card == right.card && left.openTitle == right.openTitle && left.move == right.move && left.peek == right.peek && left.number == right.number
        }
    }

    public let title: String
    public let subtitle: String?
    public let run: String
    public let picture: Icon?
    public let place: String?
    public let keywords: [String]
    public let records: Bool
    public let takesShake: Bool
    public let isOn: Bool
    public let isToggle: Bool
    public let tone: MetricValue.Tone?
    public let pin: Pin?
    private let extras: Extras?

    public enum Pin: String, Sendable {
        case top, bottom
    }

    public var isPinned: Bool {
        pin != nil
    }
    public let staysOnPick: Bool
    public let section: String?
    public let showsWords: Bool

    public var hides: [String]? { extras?.hides }
    public var shortcut: String? { extras?.shortcut }
    public var file: String? { extras?.file }
    public var fields: [TextBlock.Field] { extras?.fields ?? [] }
    public var card: SpotState? { extras?.card }
    public var openTitle: String? { extras?.openTitle }
    public var move: FlowMove? { extras?.move }
    public var peek: [TextBlock] { extras?.peek ?? [] }
    public var number: NumberReading? { extras?.number }

    public init(title: String, subtitle: String? = nil, run: String, picture: Icon? = nil, place: String? = nil, hides: [String]? = nil, keywords: [String] = [], shortcut: String? = nil, records: Bool = false, takesShake: Bool = false, isOn: Bool = false, isToggle: Bool = false, tone: MetricValue.Tone? = nil, file: String? = nil, fields: [TextBlock.Field] = [], card: SpotState? = nil, pin: Pin? = nil, openTitle: String? = nil, staysOnPick: Bool = false, move: FlowMove? = nil, section: String? = nil, number: NumberReading? = nil, showsWords: Bool = true, peek: [TextBlock] = []) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.picture = picture
        self.place = place
        self.keywords = keywords
        self.records = records
        self.takesShake = takesShake
        self.isOn = isOn
        self.isToggle = isToggle
        self.tone = tone
        self.pin = pin
        self.staysOnPick = staysOnPick
        self.section = section
        self.showsWords = showsWords
        extras = Extras(hides: hides, shortcut: shortcut, file: file, fields: fields, card: card, openTitle: openTitle, move: move, peek: peek, number: number)
    }

    var carried: [TextBlock.Field] {
        fields.map { .init(key: "item.\($0.key)", value: $0.value) }
    }

    init?(block: TextBlock, kind: BlockKind, section: String?) {
        guard let run = block.value(kind.word) else { return nil }
        let hides = block.values(ItemKey.hides)
        let records = kind == .hotkey
        let number = kind == .number || kind == .series ? NumberReading(block: block) : nil
        let style = StyleCache.shared.style(of: block.value(ViewNode.classKey) ?? "").resolved(for: [.sheet])
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
            move: FlowMove(item: block),
            section: section,
            number: number,
            showsWords: !style.hidesWords,
            peek: kind == .item && block.children.first?.fields.first?.key == BlockKind.peek.word ? block.children : []
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

    public var color: String? {
        picture?.color
    }

    public func path(in spot: Spot) -> String {
        [spot.name, place].compactMap { $0 }.joined(separator: " › ")
    }

    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? iconFile.map(FileIcon.init(path:))
    }
}
