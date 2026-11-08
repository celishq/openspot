import Foundation

/// What a script prints, sorted by the first key of each block: `row`, a kind of part, or the effects `toast` and `open`.
/// The first other block says how the spot itself looks. A button that the drawing does not place is an action (U6). Each
/// `run` value appears once.
public struct PluginOutput: Equatable, Sendable {
    public private(set) var summary: TextBlock?
    public private(set) var rows: [TextBlock] = []
    public private(set) var items: [SpotItem] = []
    public private(set) var fields: [TextBlock] = []
    public private(set) var actions: [CommandAction] = []
    public private(set) var primary: String?
    public private(set) var pick = ItemPick.close
    public private(set) var parts: [SpotPart] = []
    public private(set) var partFaults: [String] = []
    public private(set) var errors: [String] = []
    public private(set) var layout: SheetLayout?
    public private(set) var toast: String?
    /// The link of an `open` effect, such as the fix of a failure.
    public private(set) var open: String?

    private static let reserved = "read"
    /// The app's own events. A part cannot take one, and a button can take only `open`, to change the pick.
    private static let defaults = ["run", "open", "drop", "on", "off", "level"]
    private static let button = "button"

    /// Whether a first key names a row or a part, so that the block is not the head.
    private static func isKind(_ key: String) -> Bool {
        key == "row" || SpotPart.kinds.contains(key)
    }

    public init(text: String) {
        var runs = Set<String>()
        let blocks = TextBlock.blocks(in: text)
        let head = blocks.first { block in block.fields.first.map { !Self.isKind($0.key) } ?? false }
        let layout = head.flatMap(SheetLayout.init(block:))
        for block in blocks {
            let kind = block.fields.first?.key
            if kind == Self.button, let id = block.value(Self.button), layout?.areas[id] == nil {
                take(action: id, block)
            } else if kind == "row" {
                rows.append(block)
                if let item = SpotItem(block: block) {
                    if runs.insert(item.run).inserted { items.append(item) }
                } else {
                    errors.append(block.firstLine)
                }
            } else if let kind, SpotPart.kinds.contains(kind), let part = SpotPart(block: block) {
                if kind == "field" { fields.append(block) }
                parts.append(part)
                partFaults += PartCatalog.faults(in: block)
            } else if summary == nil, block == head {
                summary = block
                take(effects: block)
            } else if kind == "toast" || kind == "open" {
                take(effects: block)
            } else {
                errors.append(block.firstLine)
            }
        }
        self.layout = layout
        parts += layout?.keyParts ?? []
        for id in [Self.reserved] + Self.defaults where parts.contains(where: { $0.id == id }) {
            partFaults.append("a part cannot be called \(id)")
        }
        if !parts.isEmpty { partFaults += SheetFaults.of(layout: layout, summary: summary, parts: parts) }
    }

    /// Who searches its rows: the script when it prints `search=script`.
    public var search: ItemSearch {
        summary?.value("search") == ItemSearch.script.rawValue ? .script : .local
    }

    /// How many rows go on one line, when the script draws a repeated area.
    public var perLine: Int? {
        layout?.repeated?.perLine
    }

    /// Whether recent picks sort first, unless it prints `recents=false`.
    public var keepsRecent: Bool {
        summary?.flag("recents") != false
    }

    /// All that is wrong with this output as one sheet of parts.
    public var sheetFaults: [String] {
        (parts.isEmpty && perLine == nil ? ["the sheet has no parts"] : []) + errors.map { "cannot read the block that starts: \($0)" } + partFaults
    }

    /// The kind of spot that this output makes.
    public var kind: SpotKind {
        if !items.isEmpty || !actions.isEmpty || !parts.isEmpty { return .list }
        if summary?.number("level") != nil { return .slider }
        return summary?.flag("on") != nil ? .toggle : .launch
    }

    private mutating func take(effects block: TextBlock) {
        toast = block.value("toast") ?? toast
        open = block.value("open") ?? open
    }

    /// Keeps an action. The `open` action sets the word for Enter, and whether a pick stays in the panel.
    private mutating func take(action id: String, _ block: TextBlock) {
        if id == Self.reserved || (Self.defaults.contains(id) && id != "open") { partFaults.append("an action cannot be called \(id)") }
        if id == "open" {
            primary = block.value("title")
            pick = block.flag("close") == false ? .stay : .close
        } else if let action = CommandAction(id: id, block: block) {
            actions.append(action)
        } else {
            errors.append(block.firstLine)
        }
    }
}
