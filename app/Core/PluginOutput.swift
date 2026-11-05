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
    }

    /// How often an open sheet of parts asks to be read again, in seconds.
    public var every: TimeInterval? {
        summary?.number("every")
    }

    /// The kind of spot that this output makes.
    public var kind: SpotKind {
        if !items.isEmpty || !actions.isEmpty || !parts.isEmpty { return .list }
        if summary?.number("level") != nil { return .slider }
        return summary?.flag("on") != nil ? .toggle : .launch
    }

    /// Keeps an action. The `open` action sets the word for Enter, and whether a pick stays in the panel.
    private mutating func take(action id: String, _ block: TextBlock) {
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
