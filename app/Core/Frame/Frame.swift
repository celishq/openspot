import Foundation

public struct Frame: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let block: TextBlock
        let kind: BlockKind
    }

    public static let empty = Frame(grouped: [], kinds: [])

    public private(set) var root: TextBlock?
    public private(set) var items: [SpotItem] = []
    public private(set) var fields: [Field] = []
    public private(set) var actions: [CommandAction] = []
    public private(set) var openTitle: String?
    public private(set) var pick = ItemPick.close
    public private(set) var pickForm: CommandAction?
    public private(set) var parts: [SpotPart] = []
    public private(set) var rows: [[String]] = []
    private var every: [SpotPart] = []
    private var carded: [SpotPart]?
    private(set) var searchField: TextBlock?
    public private(set) var errors: [String] = []
    public private(set) var value: TextBlock?
    private(set) var valueKind: BlockKind?
    private var barValue: TextBlock?
    private var barKind: BlockKind?
    public private(set) var hasBar = false
    public private(set) var face = CardFace.none
    public private(set) var tree = ViewTree.empty
    public private(set) var columns = 1
    public private(set) var ends: [String] = []
    public private(set) var start: String?
    public private(set) var select: String?
    public let isPicture: Bool
    public let isMark: Bool

    static let open = "open"
    private static let sheetRoot = RootKey.block([.init(key: ViewNode.classKey, value: "gap-part")])
    private static let itemsBlock = TextBlock(fields: [.init(key: BlockKind.items, value: "items")])
    private static let searchType = "search"
    private static let sheetPlaces: [Set<Style.Variant>] = [Style.Variant.sheet, .float, .window].flatMap { place in [[place, .dark], [place, .light]] }

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

    static func placed(in tree: ViewTree) -> Set<String> {
        tree.isWritten ? Set(tree.nodes.keys).subtracting(tree.listed) : []
    }

    public init(text: String, kinds: [BlockKind] = BlockKind.all) {
        FrameParses.meter?.add()
        self.init(grouped: Self.grouping(TextBlock.blocks(in: text)), kinds: kinds)
    }

    @concurrent static func reading(_ text: String, kinds: [BlockKind] = BlockKind.all) async -> Frame {
        Frame(text: text, kinds: kinds)
    }

    init(grouped written: [TextBlock], kinds: [BlockKind]) {
        let blocks = TextBlock.patching([], with: written) { ViewTree.id(of: $0, in: kinds) }
        let frame = FrameRoot(blocks: blocks, kinds: kinds)
        isPicture = frame.isPicture
        isMark = frame.isMark
        let head = frame.block
        tree = ViewTree(blocks: blocks, root: head, kinds: kinds)
        let repeated = blocks.first { $0.fields.first?.key == BlockKind.items }?.fields.first?.value
        if let repeated, let style = tree.node(repeated)?.style.resolved(for: [.sheet]), style.arrangement == .grid {
            columns = style.columns ?? 1
        }
        let listed = tree.listed
        let placed = Self.placed(in: tree)
        let inSheet = Set(Self.sheetPlaces.flatMap(tree.shown(in:)))
        var runs = Set<String>()
        var listedRows: [TextBlock] = []
        var section: String?
        var values: [(block: TextBlock, kind: BlockKind)] = []
        var unplaced: [TextBlock] = []
        for (index, block) in blocks.enumerated() {
            let word = block.fields.first?.key
            if [BlockKind.items, BlockKind.box].contains(word) { continue }
            if let kind = BlockKind.of(block, in: kinds) {
                let id = block.value(kind.word)
                let isPlaced = id.map(placed.contains) ?? false
                if kind.presses, let id, !isPlaced {
                    take(action: id, block)
                } else if Self.isSearch(block) {
                    searchField = block
                } else if let id, listed.contains(id), tree.node(id)?.style.resolved(for: [.sheet]).font == .section {
                    section = block.value("title") ?? block.value("value")
                } else if let part = SpotPart(block: block, kind: kind) {
                    if kind.field != nil { fields.append(Field(block: block, kind: kind)) }
                    if kind.holdsValue { values.append((block, kind)) }
                    every.append(part)
                    if isPlaced {
                        if let id, inSheet.contains(id) { parts.append(part) }
                    } else if kind == .choice {
                        parts.append(part)
                        unplaced.append(block)
                    } else if let item = SpotItem(block: block, kind: kind, section: section) {
                        listedRows.append(block)
                        if runs.insert(item.run).inserted { items.append(item) }
                    }
                } else {
                    errors.append(block.firstLine)
                }
            } else if index == frame.index {
                root = block
                take(marks: block)
            } else if RootKey.isMark(block) {
                take(marks: block)
            } else {
                errors.append(block.firstLine)
            }
        }
        if parts.contains(where: { tree.node($0.id)?.source != nil }) {
            rows = listedRows.map { $0.fields.flatMap { [$0.key, $0.value] } }
        }
        face = CardFace(parts: every, tree: tree.isWritten || !tree.places.isEmpty ? tree : .empty)
        let cardSizes = SpotSize.all.filter(tree.draws(on:))
        let onCard = cardSizes.isEmpty ? nil : Set(cardSizes.flatMap { tree.shown(in: Style.Variant.card($0)) })
        if let onCard { carded = every.filter { onCard.contains($0.id) } }
        let placedValues = values.filter { (onCard ?? placed).contains($0.block.fields.first?.value ?? "") }
        let sole = placedValues.isEmpty ? values : placedValues
        let held = sole.count == 1 ? sole.first : nil
        value = held?.block
        valueKind = held?.kind
        let barred = tree.drawsOnBar ? tree.shown(in: [.bar]) : []
        let shown = barred.lazy.compactMap { id in values.first { $0.block.fields.first?.value == id } }.first
        barValue = shown?.block
        barKind = shown?.kind
        hasBar = !barred.isEmpty
        if !tree.isWritten, !parts.isEmpty {
            let itemsBlock = blocks.first { $0.fields.first?.key == BlockKind.items } ?? (items.isEmpty ? nil : Self.itemsBlock)
            tree = tree.unwritten(showing: unplaced + [itemsBlock].compactMap(\.self), root: Self.sheetRoot, kinds: kinds)
        }
    }

    private static func isSearch(_ block: TextBlock) -> Bool {
        block.fields.first?.key == BlockKind.field.word && block.value("type") == searchType
    }

    public var control: SpotPart? {
        let shown = carded ?? every
        guard actions.isEmpty, shown.count == 1, let part = shown.first else { return nil }
        switch part.control {
        case .toggle, .slider: return part
        default: return nil
        }
    }

    public var barred: Frame {
        var output = self
        output.value = barValue
        output.valueKind = barKind
        output.items = []
        return output
    }

    public var metric: TextBlock? {
        valueKind?.isReading == true ? value : nil
    }

    public var progress: Double? {
        root?.number(RootKey.progress).map { min(max($0, 0), 1) }
    }

    func selecting(_ row: String?) -> Frame {
        var output = self
        output.select = row
        return output
    }

    public func withoutEffects() -> Frame {
        var output = self
        output.select = nil
        output.ends = []
        output.start = nil
        return output
    }

    public var answers: [SpotItem] {
        guard face.answerSize != nil, let value, let run = value.value("value") else { return items }
        let title = value.value("display") ?? run
        return [SpotItem(title: title, run: run, card: SpotState(output: self, header: SpotState(title: title)), openTitle: openTitle)]
    }

    public var valuePart: SpotPart? {
        value.flatMap { block in every.first { $0.id == block.fields.first?.value } }
    }

    public var perLine: Int? {
        tree.holdsItems || searchField != nil ? columns : nil
    }

    public var search: ItemSearch {
        !tree.isWritten || searchField != nil ? .local : .off
    }

    public var keepsRecent: Bool {
        root?.flag(RootKey.recents) != false
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
        } else if BlockKind.actionFaults(in: block).isEmpty {
            errors.append(block.firstLine)
        }
    }
}
