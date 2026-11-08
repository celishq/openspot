import Foundation

/// What a script prints, sorted by the key that says what each block is: `row`, `action`, `field`, `part` or `section`.
/// The first other block says how the spot itself looks. Each `run` value appears once.
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

    private static let reserved = "read"
    /// The app's own events. A part cannot take one, and an action can take only `open`, to change the pick.
    private static let defaults = ["run", "open", "drop", "on", "off", "level"]

    public init(text: String) {
        var runs = Set<String>()
        for block in TextBlock.blocks(in: text) {
            if block.value("row") != nil {
                rows.append(block)
                if let item = SpotItem(block: block) {
                    if runs.insert(item.run).inserted { items.append(item) }
                } else {
                    errors.append(block.firstLine)
                }
            } else if let id = block.value("action") {
                take(action: id, block)
            } else if block.value("field") != nil {
                fields.append(block)
            } else if let part = SpotPart(block: block) {
                parts.append(part)
                partFaults += PartCatalog.faults(in: block)
            } else if summary == nil, !block.fields.isEmpty {
                summary = block
            } else {
                errors.append(block.firstLine)
            }
        }
        layout = summary.flatMap(SheetLayout.init(block:))
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
