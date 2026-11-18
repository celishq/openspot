import Foundation

public struct SpotOutput: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let block: TextBlock
        let kind: BlockKind
    }

    public static let empty = SpotOutput(grouped: [], kinds: [])

    public private(set) var summary: TextBlock?
    public private(set) var items: [SpotItem] = []
    public private(set) var fields: [Field] = []
    public private(set) var actions: [CommandAction] = []
    public private(set) var openTitle: String?
    public private(set) var pick = ItemPick.close
    public private(set) var pickForm: CommandAction?
    public private(set) var parts: [SpotPart] = []
    private var every: [SpotPart] = []
    private(set) var searchField: TextBlock?
    public private(set) var errors: [String] = []
    public private(set) var layout: SheetLayout?
    public private(set) var value: TextBlock?
    private(set) var valueKind: BlockKind?
    private var barValue: TextBlock?
    private var barKind: BlockKind?
    public private(set) var hasBar = false
    public private(set) var view: TextBlock?
    public private(set) var face = CardFace.none
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var toast: String?
    public private(set) var ends: [String] = []
    public private(set) var start: String?
    public private(set) var select: String?
    public let isPicture: Bool
    public let isMark: Bool

    static let open = "open"
    static let itemsArea = "items"
    private static let searchType = "search"
    private static let spotFilter = "spot"

    static func grouping(_ blocks: [TextBlock]) -> [TextBlock] {
        var grouped: [TextBlock] = []
        var choice: Int?
        for block in blocks {
            let kind = block.fields.first?.key
            if kind == BlockKind.option, let index = choice {
                grouped[index] = grouped[index].adding(child: block)
            } else {
                choice = kind == BlockKind.choice.word ? grouped.count : nil
                grouped.append(block)
            }
        }
        return grouped
    }

    static func placed(by head: TextBlock?) -> Set<String> {
        let drawn = head.flatMap { SheetLayout(block: $0) }
        return Set(CardFace(head: head, parts: []).drawings.values.flatMap { $0.joined() }).union(drawn?.areas.keys.map { $0 } ?? [])
    }

    public init(text: String, kinds: [BlockKind] = BlockKind.all) {
        FrameParses.meter?.add()
        self.init(grouped: Self.grouping(TextBlock.blocks(in: text)), kinds: kinds)
    }

    @concurrent static func reading(_ text: String) async -> SpotOutput {
        SpotOutput(text: text)
    }

    init(grouped blocks: [TextBlock], kinds: [BlockKind]) {
        let frame = FrameRoot(blocks: blocks, kinds: kinds)
        isPicture = frame.isPicture
        isMark = frame.isMark
        let head = frame.block
        let repeats = blocks.filter { $0.fields.first?.key == BlockKind.repeated }
        let repeated = repeats.first.flatMap { block in block.value(BlockKind.repeated).map { (block, $0) } }
        if let (block, _) = repeated { drawing = RepeatDrawing(block: block) }
        let placed = Self.placed(by: head)
        let inSheet = head.flatMap { SheetLayout(block: $0) }.map { Set($0.areas.keys) }
        var runs = Set<String>()
        var listed: [TextBlock] = []
        var section: String?
        var values: [(block: TextBlock, kind: BlockKind)] = []
        for (index, block) in blocks.enumerated() {
            let word = block.fields.first?.key
            if word == BlockKind.repeated { continue }
            if let kind = BlockKind.of(block, in: kinds) {
                let id = block.value(kind.word)
                let isPlaced = id.map(placed.contains) ?? false
                if kind.presses, let id, !isPlaced {
                    take(action: id, block)
                } else if Self.isSearch(block) {
                    searchField = block
                } else if kind == .section, !isPlaced {
                    section = block.value("title")
                } else if let part = SpotPart(block: block, kind: kind) {
                    if kind.field != nil { fields.append(Field(block: block, kind: kind)) }
                    if view == nil, kind.isOpen { view = block }
                    if kind.holdsValue { values.append((block, kind)) }
                    every.append(part)
                    if isPlaced {
                        if let id, inSheet?.contains(id) ?? true { parts.append(part) }
                    } else if kind == .choice {
                        parts.append(part)
                    } else if let item = SpotItem(block: block, kind: kind, section: section) {
                        listed.append(block)
                        if runs.insert(item.run).inserted { items.append(item) }
                    }
                } else {
                    errors.append(block.firstLine)
                }
            } else if index == frame.index {
                summary = block
                take(marks: block)
            } else if RootKey.isMark(block) {
                take(marks: block)
            } else if word == SheetFrames.notice {
                toast = block.value(SheetFrames.notice)
            } else {
                errors.append(block.firstLine)
            }
        }
        let repeating = repeated.map { (area: $0.1, perLine: drawing.perLine ?? drawing.columns) }
            ?? (!items.isEmpty && !parts.isEmpty ? (area: Self.itemsArea, perLine: 1) : nil)
        let layout = SheetLayout(block: head, repeating: repeating, repeats: repeats.count, skipping: searchField?.fields.first?.value)
            ?? repeating.map { SheetLayout(flat: parts, repeating: $0) }
        self.layout = layout
        let fields = listed.map { $0.fields.flatMap { [$0.key, $0.value] } }
        parts = parts.map { $0.drawn(in: layout).holding(rows: fields) }
        face = CardFace(head: head, parts: every)
        let placedValues = values.filter { placed.contains($0.block.fields.first?.value ?? "") }
        let sole = placedValues.isEmpty ? values : placedValues
        let held = sole.count == 1 ? sole.first : nil
        value = held?.block
        valueKind = held?.kind
        let barred = face.drawings[CardFace.bar]?.flatMap { $0 } ?? []
        let shown = barred.lazy.compactMap { id in values.first { $0.block.fields.first?.value == id } }.first
        barValue = shown?.block
        barKind = shown?.kind
        hasBar = !barred.isEmpty
    }

    private static func isSearch(_ block: TextBlock) -> Bool {
        block.fields.first?.key == BlockKind.field.word && block.value("type") == searchType
    }

    public var control: SpotPart? {
        guard actions.isEmpty, every.count == 1, let part = every.first else { return nil }
        switch part.control {
        case .toggle, .slider: return part
        default: return nil
        }
    }

    public var barred: SpotOutput {
        var output = self
        output.value = barValue
        output.valueKind = barKind
        output.items = []
        return output
    }

    public var metric: TextBlock? {
        valueKind?.data == nil ? nil : value
    }

    var metricData: BlockKind.Data? {
        value.flatMap { valueKind?.data?($0) }
    }

    public var progress: Double? {
        summary?.number(RootKey.progress).map { min(max($0, 0), 1) }
    }

    func selecting(_ row: String?) -> SpotOutput {
        var output = self
        output.select = row
        return output
    }

    public func withoutEffects() -> SpotOutput {
        var output = self
        output.toast = nil
        output.select = nil
        output.ends = []
        output.start = nil
        return output
    }

    public var answers: [SpotItem] {
        guard face.answerSize != nil, let value, let run = value.value("value") else { return items }
        let title = value.value("display") ?? run
        return [SpotItem(title: title, run: run, card: SpotState(output: self, header: SpotState(title: title)).holding(view), openTitle: openTitle)]
    }

    public var valuePart: SpotPart? {
        value.flatMap { block in every.first { $0.id == block.fields.first?.value } }
    }

    public var perLine: Int? {
        layout?.repeated?.perLine
    }

    public var search: ItemSearch {
        if searchField?.value("filter") == Self.spotFilter { return .script }
        return searchField != nil || summary?.value(RootKey.grid) == nil ? .local : .off
    }

    public var keepsRecent: Bool {
        summary?.flag(RootKey.recents) != false
    }

    public var kind: SpotKind {
        if case .toggle? = control?.control { return .toggle }
        if control != nil { return .slider }
        return .list
    }

    private mutating func take(marks block: TextBlock) {
        if let end = block.value(RootKey.end) { ends.append(end) }
        start = block.value(RootKey.call) ?? start
    }

    private mutating func take(action id: String, _ block: TextBlock) {
        if id == Self.open {
            openTitle = block.value("title")
            pick = block.flag("close") == false ? .stay : .close
            if block.flag("form") == true {
                pickForm = CommandAction(id: id, title: openTitle ?? "Open", after: pick == .close ? .close : .stay, isForm: true)
            }
        } else if let action = CommandAction(id: id, block: block) {
            actions.append(action)
        } else if PartCatalog.actionFaults(in: block).isEmpty {
            errors.append(block.firstLine)
        }
    }
}
