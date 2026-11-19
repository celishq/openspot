import Foundation

public struct BlockKind: Sendable, Equatable {
    public typealias Data = (value: Double?, points: [Double]?)

    public static let row = "row"
    public static let repeated = "repeat"
    public static let option = "option"

    public let name: String
    public let word: String
    let picks: @Sendable (TextBlock) -> Bool
    let keys: Set<String>
    let isOpen: Bool
    let holdsValue: Bool
    let takesColor: Bool
    let presses: Bool
    let looks: [String: SpotPart.Look]
    let control: @Sendable (TextBlock) -> SpotPart.Control
    let faults: @Sendable (TextBlock) -> [String]
    let data: (@Sendable (TextBlock) -> Data)?
    let field: (@Sendable (TextBlock, String, String) -> ItemForm.Field)?

    init(
        name: String,
        word: String? = nil,
        picks: @escaping @Sendable (TextBlock) -> Bool = { _ in true },
        keys: Set<String> = [],
        isOpen: Bool = false,
        holdsValue: Bool = false,
        takesColor: Bool = false,
        presses: Bool = false,
        looks: [String: SpotPart.Look] = [:],
        control: @escaping @Sendable (TextBlock) -> SpotPart.Control = { _ in .none },
        faults: @escaping @Sendable (TextBlock) -> [String] = PartCatalog.keyFaults,
        data: (@Sendable (TextBlock) -> Data)? = nil,
        field: (@Sendable (TextBlock, String, String) -> ItemForm.Field)? = nil
    ) {
        self.name = name
        self.word = word ?? name
        self.picks = picks
        self.keys = keys
        self.isOpen = isOpen
        self.holdsValue = holdsValue
        self.takesColor = takesColor
        self.presses = presses
        self.looks = looks
        self.control = control
        self.faults = faults
        self.data = data
        self.field = field
    }

    public static func == (first: BlockKind, second: BlockKind) -> Bool {
        first.name == second.name
    }

    public static let all = [text, number, gauge, graph, picture, view, toggle, slider, hotkey, field, choice, button, section]

    static let listWords = [row, repeated, option]

    public static var words: Set<String> {
        Set(all.map(\.word) + listWords)
    }

    static func of(_ block: TextBlock, in kinds: [BlockKind]) -> BlockKind? {
        guard let word = block.fields.first?.key else { return nil }
        return kinds.first { $0.word == word && $0.picks(block) }
    }

    func formField(of block: TextBlock) -> ItemForm.Field? {
        guard let field, let name = block.value(word), let label = block.value("title") else { return nil }
        return field(block, name, label)
    }

    static let text = BlockKind(
        name: "text",
        holdsValue: true,
        takesColor: true,
        data: { block in block.value("max") == nil ? (block.number("value"), nil) : (nil, points(of: block)) }
    )

    static let number = BlockKind(
        name: "number",
        holdsValue: true,
        takesColor: true,
        control: { .number($0.value("display") ?? $0.value("value") ?? "", unit: $0.value("unit").flatMap { $0.isEmpty ? nil : $0 }) },
        data: { _ in (nil, nil) }
    )

    static let gauge = BlockKind(
        name: "gauge",
        word: "graph",
        picks: { $0.values("value").count == 1 && $0.value("max") == nil },
        holdsValue: true,
        control: { .progress(level: ($0.number("value") ?? 0) * 100) },
        data: { ($0.number("value"), nil) }
    )

    static let graph = BlockKind(
        name: "graph",
        holdsValue: true,
        control: { .chart($0.values("value").compactMap(Double.init)) },
        data: { (nil, points(of: $0)) }
    )

    static let picture = BlockKind(name: "picture", control: { Icon(text: $0.value("icon"))?.image.map(SpotPart.Control.image) ?? .none })

    static let view = BlockKind(name: "view", isOpen: true)

    static let toggle = BlockKind(
        name: "switch",
        holdsValue: true,
        looks: ["tick": .tick],
        control: { .toggle($0.flag("value") ?? false) },
        field: { block, name, label in ItemForm.Field(name: name, label: label, type: .switch, value: block.flag("value") == true ? "true" : "false") }
    )

    static let slider = BlockKind(
        name: "slider",
        word: "field",
        picks: { $0.value("type") == "slider" },
        holdsValue: true,
        control: { block in
            let range = range(of: block)
            return .slider(level: block.number("value") ?? 0, min: range.low, max: range.high)
        },
        faults: { block in
            let range = range(of: block)
            guard let level = block.number("value"), level < range.low || level > range.high else { return PartCatalog.keyFaults(in: block) }
            let fault = "the part \(block.fields.first?.value ?? "") has a level of \(Int(level)), outside \(Int(range.low)) to \(Int(range.high))"
            return [fault] + PartCatalog.keyFaults(in: block)
        },
        field: { block, name, label in
            let low = range(of: block).low
            let range = low...max(range(of: block).high, low + 1)
            let level = min(max(block.number("value") ?? low, range.lowerBound), range.upperBound)
            return ItemForm.Field(name: name, label: label, type: .slider, value: String(Int(level.rounded())), range: range)
        }
    )

    static let hotkey = BlockKind(
        name: "hotkey",
        word: "field",
        picks: { $0.value("type") == "hotkey" },
        control: { .shortcut($0.value("value") ?? "") },
        faults: { block in
            guard let shortcut = block.value("value"), Shortcut(text: shortcut) == nil else { return [] }
            return ["the part \(block.fields.first?.value ?? "") needs a shortcut that holds cmd, ctrl or option: \(shortcut)"]
        }
    )

    static let field = BlockKind(
        name: "field",
        control: { block in
            guard block.value("type") != ItemForm.Field.Kind.secret.rawValue else { return .secret(block.value("value") ?? "", placeholder: block.value("placeholder")) }
            return .text(block.value("value") ?? "", placeholder: block.value("placeholder"), isReadOnly: block.flag("readonly") ?? false)
        },
        field: { block, name, label in
            let type = ItemForm.Field.Kind(rawValue: block.value("type") ?? "").flatMap { [.multiline, .secret].contains($0) ? $0 : nil } ?? .text
            return ItemForm.Field(name: name, label: label, type: type, value: block.value("value"), required: block.flag("required"), placeholder: block.value("placeholder"))
        }
    )

    static let choice = BlockKind(
        name: "choice",
        control: { block in
            let colors = block.values("color")
            return colors.isEmpty ? .menu(SpotPart.options(of: block), value: block.value("value")) : .swatches(colors, value: block.value("value"))
        },
        field: { block, name, label in
            let options = SpotPart.options(of: block)
            guard block.value("type") == "multiple" else {
                return ItemForm.Field(name: name, label: label, type: .choice, value: block.value("value") ?? options.first?.id, options: options)
            }
            return ItemForm.Field(name: name, label: label, type: .choice, value: options.first?.id, options: options, picks: Set(block.values("value")))
        }
    )

    static let button = BlockKind(name: "button", presses: true, faults: PartCatalog.shortcutFaults)

    static let section = BlockKind(name: "section")

    private static func points(of block: TextBlock) -> [Double]? {
        let points = block.values("value").compactMap(Double.init).filter(\.isFinite)
        return points.isEmpty ? nil : points
    }

    private static func range(of block: TextBlock) -> (low: Double, high: Double) {
        (block.number("min") ?? 0, block.number("max") ?? 100)
    }
}
