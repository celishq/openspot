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
    public private(set) var errors: [String] = []
    public private(set) var layout: SheetLayout?
    public private(set) var value: TextBlock?
    private(set) var valueKind: BlockKind?
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
    private static let rowsArea = "rows"

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
        var runs = Set<String>()
        var rows: [TextBlock] = []
        var values: [(block: TextBlock, kind: BlockKind)] = []
        for (index, block) in blocks.enumerated() {
            let word = block.fields.first?.key
            if word == BlockKind.repeated { continue }
            if word == BlockKind.row {
                rows.append(block)
                if let item = SpotItem(block: block) {
                    if runs.insert(item.run).inserted { items.append(item) }
                } else {
                    errors.append(block.firstLine)
                }
            } else if let kind = BlockKind.of(block, in: kinds) {
                if kind.presses, let id = block.value(kind.word), !placed.contains(id) {
                    take(action: id, block)
                } else if let part = SpotPart(block: block, kind: kind) {
                    if kind.field != nil { fields.append(Field(block: block, kind: kind)) }
                    if view == nil, kind.isOpen { view = block }
                    if kind.holdsValue { values.append((block, kind)) }
                    parts.append(part)
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
            ?? (!rows.isEmpty && !parts.isEmpty ? (area: Self.rowsArea, perLine: 1) : nil)
        let layout = SheetLayout(block: head, repeating: repeating, repeats: repeats.count)
            ?? repeating.map { SheetLayout(flat: parts, repeating: $0) }
        self.layout = layout
        let fields = rows.map { $0.fields.flatMap { [$0.key, $0.value] } }
        parts = parts.map { $0.drawn(in: layout).holding(rows: fields) }
        face = CardFace(head: head, parts: parts)
        let main = head?.value(RootKey.main)
        let held = main.map { id in values.first { $0.block.fields.first?.value == id } } ?? (values.count == 1 ? values.first : nil)
        value = held?.block
        valueKind = held?.kind
    }

    public var control: SpotPart? {
        guard items.isEmpty, actions.isEmpty, parts.count == 1, let part = parts.first else { return nil }
        switch part.control {
        case .toggle, .slider: return part
        default: return nil
        }
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
        value.flatMap { block in parts.first { $0.id == block.fields.first?.value } }
    }

    public var perLine: Int? {
        layout?.repeated?.perLine
    }

    public var hidesSearch: Bool {
        summary?.value(RootKey.search) == "off"
    }

    public var keepsRecent: Bool {
        summary?.flag(RootKey.recents) != false
    }

    public var kind: SpotKind {
        if case .toggle? = control?.control { return .toggle }
        if control != nil { return .slider }
        return items.isEmpty && actions.isEmpty && parts.isEmpty ? .launch : .list
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
