import Foundation

public struct BlockKind: Sendable, Equatable {
    public let name: String
    public let word: String
    let picks: @Sendable (TextBlock) -> Bool
    let keys: Set<String>
    let isOpen: Bool
    let holdsValue: Bool
    let isReading: Bool
    let takesColor: Bool
    let presses: Bool
    let takesTick: Bool
    let control: @Sendable (TextBlock) -> SpotPart.Control
    let faults: @Sendable (TextBlock) -> [String]
    let field: (@Sendable (TextBlock, String, String) -> ItemForm.Field)?
    let source: String?

    init(
        name: String,
        word: String? = nil,
        picks: @escaping @Sendable (TextBlock) -> Bool = { _ in true },
        keys: Set<String> = [],
        isOpen: Bool = false,
        holdsValue: Bool = false,
        isReading: Bool = false,
        takesColor: Bool = false,
        presses: Bool = false,
        takesTick: Bool = false,
        control: @escaping @Sendable (TextBlock) -> SpotPart.Control = { _ in .none },
        faults: @escaping @Sendable (TextBlock) -> [String] = BlockKind.keyFaults,
        field: (@Sendable (TextBlock, String, String) -> ItemForm.Field)? = nil,
        source: String? = nil
    ) {
        self.name = name
        self.word = word ?? name
        self.picks = picks
        self.keys = keys
        self.isOpen = isOpen
        self.holdsValue = holdsValue
        self.isReading = isReading
        self.takesColor = takesColor
        self.presses = presses
        self.takesTick = takesTick
        self.control = control
        self.faults = faults
        self.field = field
        self.source = source
    }

    init(view word: String, source: String) {
        self.init(name: word, isOpen: true, faults: { _ in [] }, source: source)
    }

    public static func kinds(views: [String: String]) -> [BlockKind] {
        views.isEmpty ? all : all + views.sorted { $0.key < $1.key }.map { BlockKind(view: $0.key, source: $0.value) }
    }

    public static func == (first: BlockKind, second: BlockKind) -> Bool {
        first.name == second.name
    }

    public static let all = [text, item, number, series, picture, icon, toggle, slider, hotkey, field, choice, button]

    static let lists = [items, option, box, peek]

    static let wordsKinds = [text, item]

    public static let controls = [button, field, slider, hotkey, toggle, choice, number, series]

    public static var words: Set<String> {
        Set((all + lists).map(\.word))
    }

    static func of(_ block: TextBlock, in kinds: [BlockKind]) -> BlockKind? {
        guard let word = block.fields.first?.key else { return nil }
        return kinds.first { $0.word == word && $0.picks(block) }
    }

    func formField(of block: TextBlock) -> ItemForm.Field? {
        guard let field, let name = block.value(word), let label = block.value("title") else { return nil }
        return field(block, name, label)
    }

    public static let text = BlockKind(
        name: "text",
        holdsValue: true,
        isReading: true,
        takesColor: true
    )

    public static let item = BlockKind(
        name: "item",
        keys: Set(ItemKey.allCases.map(\.rawValue)),
        holdsValue: true,
        isReading: true,
        takesColor: true
    )

    public static let number = BlockKind(
        name: "number",
        holdsValue: true,
        isReading: true,
        takesColor: true,
        control: { .number(NumberReading(block: $0)) },
        faults: { block in
            let id = block.value("number") ?? ""
            var faults = BlockKind.keyFaults(in: block)
            if block.values("value").count > 1 {
                faults.append("the number \(id) has more than one value. Print points over time as a series, with value=1,2,3")
            }
            if let type = block.value("type") {
                if NumberLook(type: type) == nil {
                    faults.append("the part \(id) has an unknown type: \(type). Use ring or bar")
                } else if block.number("max") == nil {
                    faults.append("the number \(id) has type=\(type), which needs a max")
                }
            }
            return faults
        }
    )

    public static let series = BlockKind(
        name: "series",
        keys: ["add", "keep"],
        holdsValue: true,
        isReading: true,
        control: { .number(NumberReading(block: $0)) },
        faults: { block in
            let id = block.value("series") ?? ""
            var faults = BlockKind.keyFaults(in: block)
            if block.values("value").count > 1 {
                faults.append("the series \(id) has more than one value line. Print its points on one line, as value=1,2,3")
            }
            if let type = block.value("type") { faults.append("the part \(id) has an unknown type: \(type)") }
            return faults
        }
    )

    public static let picture = BlockKind(name: "picture", control: { Icon(text: $0.value("icon"))?.image.map(SpotPart.Control.image) ?? .none })

    public static let icon = BlockKind(name: "icon")

    public static let toggle = BlockKind(
        name: "switch",
        holdsValue: true,
        takesTick: true,
        control: { .toggle($0.flag("value") ?? false) },
        field: { block, name, label in ItemForm.Field(name: name, label: label, type: .switch, value: block.flag("value") == true ? "true" : "false") }
    )

    public static let slider = BlockKind(
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
            guard let level = block.number("value"), level < range.low || level > range.high else { return BlockKind.keyFaults(in: block) }
            let fault = "the part \(block.fields.first?.value ?? "") has a level of \(Int(level)), outside \(Int(range.low)) to \(Int(range.high))"
            return [fault] + BlockKind.keyFaults(in: block)
        },
        field: { block, name, label in
            let low = range(of: block).low
            let range = low...max(range(of: block).high, low + 1)
            let level = min(max(block.number("value") ?? low, range.lowerBound), range.upperBound)
            return ItemForm.Field(name: name, label: label, type: .slider, value: String(Int(level.rounded())), range: range)
        }
    )

    public static let hotkey = BlockKind(
        name: "hotkey",
        word: "field",
        picks: { $0.value("type") == "hotkey" },
        control: { .shortcut($0.value("value") ?? "") },
        faults: { block in
            guard let shortcut = block.value("value"), Shortcut(text: shortcut) == nil else { return [] }
            return ["the part \(block.fields.first?.value ?? "") needs a shortcut that holds cmd, ctrl or option: \(shortcut)"]
        }
    )

    public static let field = BlockKind(
        name: "field",
        control: { .text($0.value("value") ?? "", placeholder: $0.value("placeholder"), isReadOnly: $0.flag("readonly") ?? false) },
        field: { block, name, label in
            let type: ItemForm.Field.Kind = block.value("type") == ItemForm.Field.Kind.multiline.rawValue ? .multiline : .text
            return ItemForm.Field(name: name, label: label, type: type, value: block.value("value"), required: block.flag("required"), placeholder: block.value("placeholder"))
        }
    )

    public static let choice = BlockKind(
        name: "choice",
        control: { block in
            switch block.value("type") {
            case "swatches": .swatches(block.values("color"), value: block.value("value"))
            case "list": .list(SpotPart.options(of: block), value: block.value("value"))
            default: .menu(SpotPart.options(of: block), value: block.value("value"))
            }
        },
        faults: { block in
            guard block.value("type") != "swatches", !block.values("color").isEmpty else { return BlockKind.keyFaults(in: block) }
            return ["the choice \(block.value("choice") ?? "") has color lines, which only a choice with type=swatches takes"] + BlockKind.keyFaults(in: block)
        },
        field: { block, name, label in
            let options = SpotPart.options(of: block)
            guard block.value("type") == "multiple" else {
                return ItemForm.Field(name: name, label: label, type: .choice, value: block.value("value") ?? options.first?.id, options: options)
            }
            return ItemForm.Field(name: name, label: label, type: .choice, value: options.first?.id, options: options, picks: Set(block.values("value")))
        }
    )

    public static let button = BlockKind(name: "button", keys: [PeekAct.key], presses: true)

    public static let items = BlockKind(name: "items")

    public static let option = BlockKind(name: "option")

    public static let box = BlockKind(name: "box")

    public static let peek = BlockKind(name: "peek")

    private static func range(of block: TextBlock) -> (low: Double, high: Double) {
        (block.number("min") ?? 0, block.number("max") ?? 100)
    }
}
