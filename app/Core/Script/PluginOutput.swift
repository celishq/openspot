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
    /// The block of the first `text`, `gauge` or `graph`, which is the value of a metric (H1).
    public private(set) var metric: TextBlock?
    /// The block of the first `view`, whose keys the plugin's view reads (V4).
    public private(set) var view: TextBlock?
    /// The drawings of the spot's card and of the menu bar, with the components that they place (U5).
    public private(set) var face = CardFace.none
    /// The drawing that the rows flow through (U7). With no `repeat` block, the rows are a list.
    public private(set) var drawing = RepeatDrawing.list
    /// Each template that draws rows, by its name (U8).
    public private(set) var templates: [String: RowTemplate] = [:]
    public private(set) var toast: String?
    /// The link of an `open` effect, such as the fix of a failure.
    public private(set) var open: String?

    private static let reserved = "read"
    /// The app's own events. A part cannot take one, and a button can take only `open`, to change the pick.
    private static let defaults = ["run", "open", "drop"]
    private static let button = "button"
    private static let repeatKind = "repeat"
    private static let templateKind = "template"

    /// Whether a first key names a row or a part, so that the block is not the head.
    private static func isKind(_ key: String) -> Bool {
        key == "row" || key == repeatKind || key == templateKind || SpotPart.kinds.contains(key)
    }

    public init(text: String) {
        var runs = Set<String>()
        let blocks = TextBlock.blocks(in: text)
        let head = blocks.first { block in block.fields.first.map { !Self.isKind($0.key) } ?? false }
        let repeats = blocks.filter { $0.fields.first?.key == Self.repeatKind }
        let repeated = repeats.first.flatMap { block in block.value(Self.repeatKind).map { (block, $0) } }
        if let (block, _) = repeated { drawing = RepeatDrawing(block: block) }
        let layout = SheetLayout(
            block: head,
            repeating: repeated.map { (area: $0.1, perLine: drawing.perLine ?? drawing.columns) },
            repeats: repeats.count
        )
        for block in blocks {
            let kind = block.fields.first?.key
            if kind == Self.repeatKind { continue }
            if kind == Self.templateKind {
                if let template = RowTemplate(block: block) { templates[template.name] = template } else { errors.append(block.firstLine) }
            } else if kind == Self.button, let id = block.value(Self.button), layout?.areas[id] == nil {
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
                if metric == nil, ["text", "gauge", "graph"].contains(kind) { metric = block }
                if view == nil, kind == "view" { view = block }
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
        face = CardFace(head: head, parts: parts)
        if let id = face.trayID, let block = blocks.first(where: { $0.fields.first?.value == id && ["text", "gauge", "graph"].contains($0.fields.first?.key ?? "") }) {
            metric = block
        }
        for drawing in face.drawings.values {
            for id in Set(drawing.joined()) where id != SheetLayout.empty && !parts.contains(where: { $0.id == id }) {
                partFaults.append("the card drawing names \(id), which no component has")
            }
        }
        parts += layout?.keyParts ?? []
        for id in [Self.reserved] + Self.defaults where parts.contains(where: { $0.id == id }) {
            partFaults.append("a part cannot be called \(id)")
        }
        if !parts.isEmpty { partFaults += SheetFaults.of(layout: layout, summary: summary, parts: parts) }
    }

    /// The one switch or slider that is all the output, which the card draws and changes (U12).
    public var control: SpotPart? {
        guard items.isEmpty, actions.isEmpty, parts.count == 1, let part = parts.first else { return nil }
        return part.kind == "switch" || part.kind == "slider" ? part : nil
    }

    /// Who searches its rows: the script when it prints `search=script`.
    public var search: ItemSearch {
        summary?.value("search") == ItemSearch.script.rawValue ? .script : .local
    }

    /// How many rows go on one line, when the script prints a repeat.
    public var perLine: Int? {
        layout?.repeated?.perLine
    }

    /// The template that draws a row: the one it names, or else `template=row`.
    public func template(of item: SpotItem) -> RowTemplate? {
        templates[item.template ?? RowTemplate.defaultName]
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
        if let control { return control.kind == "switch" ? .toggle : .slider }
        return items.isEmpty && actions.isEmpty && parts.isEmpty ? .launch : .list
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
