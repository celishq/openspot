import Foundation

/// One frame of what a script prints, sorted by the first key of each block: `row` or a kind of part. The one other block is
/// the head, which says how the spot itself looks and holds the effects `toast`, `link`, `select`, `progress` and `end`. A
/// frame with a block is the whole picture, and a frame of only a head carries effects. A button that the drawing does
/// not place is an action (protocol: Buttons and actions). Each `run` value appears once.
public struct SpotOutput: Equatable, Sendable {
    public private(set) var summary: TextBlock?
    public private(set) var rows: [TextBlock] = []
    public private(set) var items: [SpotItem] = []
    /// The blocks that a form takes: each `field`, `choice`, `switch` and `slider`.
    public private(set) var fields: [TextBlock] = []
    public private(set) var actions: [CommandAction] = []
    public private(set) var primary: String?
    public private(set) var pick = ItemPick.close
    /// The form that Enter on a row asks with first, when `button=open` has `form=true`.
    public private(set) var pickForm: CommandAction?
    public private(set) var parts: [SpotPart] = []
    public private(set) var errors: [String] = []
    /// Each word of an older protocol that the output prints, with the word that took its place.
    public private(set) var retired: [String] = []
    public private(set) var layout: SheetLayout?
    /// The block of the component that stands for the spot (protocol: The main block and the card): the one that `main=<id>` in the head names, or else the
    /// only `text`, `gauge`, `graph`, `switch` or `slider`.
    public private(set) var value: TextBlock?
    /// The block of the first `view`, whose keys the plugin's view reads (protocol: Views).
    public private(set) var view: TextBlock?
    /// The drawings of the spot's card and of the menu bar, with the components that they place (protocol: Drawings).
    public private(set) var face = CardFace.none
    /// The drawing that the rows flow through (protocol: Rows). With no `repeat` block, the rows are a list.
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var toast: String?
    /// The URL of a `link` effect, which opens it, such as the fix of a failure.
    public private(set) var link: String?
    /// The ids of the calls of a staying script that this frame ends.
    public private(set) var ends: [String] = []
    /// The id of the call of a staying script whose output starts after this frame, from `call=<n>` in its head (protocol: Modes).
    public private(set) var start: String?
    /// The blocks it was read from, which a check of its parts reads again.
    private var blocks: [TextBlock]
    /// Whether this reading checks each part, which only a check asks for, so that a frame on screen costs no check.
    private let checks: Bool
    private var checkedFaults: [String] = []
    /// The row that a `select` effect selects when the call ends, such as the row that a drop added (protocol: The calls).
    public private(set) var select: String?
    /// Whether it holds a block, so that it is the whole picture of the spot.
    public let isPicture: Bool

    private static let reserved = "read"
    /// The app's own events. A part cannot take one, and a button can take only `open`, to change the pick.
    private static let defaults = ["open", "drop"]

    /// The newer events that this output asks for: `drag` when a row names a file (protocol: Files out).
    private var takenDefaults: [String] {
        blocks.contains { $0.fields.first?.key == "row" && $0.value("file") != nil } ? ["drag"] : []
    }
    /// The keys of stdin, which no part or action can take as its id (protocol: Blocks).
    private static let inputKeys = ["search", "form", "value"]
    private static let button = "button"
    private static let repeatKind = "repeat"
    private static let optionKind = "option"
    /// The kinds of block that Openspot no longer reads. Each one is skipped and reported, so it never takes the place of the
    /// head.
    private static let retiredKinds: Set<String> = ["template", "spot", retired]
    /// The first key that a block of a folded kind takes, so that it is skipped and reported with its own first line.
    private static let retired = "retired"
    /// The kinds that the protocol folded into others: `gauge` into a `graph`, and `slider` and `hotkey` into a `field`.
    private static let foldedKinds: Set<String> = ["gauge", "slider", "hotkey"]
    /// The area of the rows in the default drawing of a sheet with no `repeat` block (protocol: Drawings).
    private static let rowsArea = "rows"
    private static let formKinds: Set<String> = ["field", "choice", "switch", "slider"]
    /// The kinds of component that can stand for the spot.
    private static let valueKinds: Set<String> = ["text", "number", "gauge", "graph", "switch", "slider"]

    /// Whether a first key names a row or a part, so that the block is not the head.
    private static func isKind(_ key: String) -> Bool {
        key == "row" || key == repeatKind || key == optionKind || retiredKinds.contains(key) || SpotPart.kinds.contains(key)
    }

    /// The pictures on the web that its blocks name, which a render fetches before it draws.
    public var webPictures: [String] {
        blocks.flatMap { [$0] + $0.children }.compactMap { $0.value("icon") }.filter(WebPictures.isWeb)
    }

    /// Folds the `option` blocks right after a choice into it. An option with no choice before it stays, and is reported.
    private static func grouping(_ blocks: [TextBlock]) -> [TextBlock] {
        var grouped: [TextBlock] = []
        var choice: Int?
        for block in blocks {
            let kind = block.fields.first?.key
            if kind == optionKind, let index = choice {
                grouped[index] = grouped[index].adding(child: block)
            } else {
                choice = kind == "choice" ? grouped.count : nil
                grouped.append(block)
            }
        }
        return grouped
    }

    public init(text: String) {
        let blocks = TextBlock.blocks(in: text)
        self.init(blocks: blocks.map(Self.drawn), checks: false)
        retired = blocks.compactMap(Self.retiredWord)
    }

    /// The fault of a block that prints a word of an older protocol, which names the word that took its place.
    private static func retiredWord(of block: TextBlock) -> String? {
        guard let first = block.fields.first else { return nil }
        switch first.key {
        case "gauge": return "gauge=\(first.value) is now a graph. Write graph=\(first.value) with one value from 0 to 1."
        case "slider", "hotkey": return "\(first.key)=\(first.value) is now a field. Write field=\(first.value) with type=\(first.key)."
        case "switch" where block.value("look") == "tick": return "The switch \(first.value) has look=tick, which Openspot no longer reads. Write type=tick."
        case _ where !isKind(first.key) && block.value("search") == "script":
            return "The head has search=script, which Openspot no longer reads. Write on=sheet.text in the header."
        default: return nil
        }
    }

    /// The errors of blocks that are no word of an older protocol, which `retired` names apart.
    var unreadable: [String] {
        errors.filter { line in !Self.foldedKinds.contains(String(line.prefix { $0 != "=" })) }
    }

    /// Reads a frame on another thread, so that a panel or a sheet in motion keeps its frames.
    static func reading(_ text: String) async -> SpotOutput {
        await Task.detached(priority: .userInitiated) { SpotOutput(text: text) }.value
    }

    /// The block as a part reads it: a `graph` of one value and no `max` is a gauge, a `field` of `type=slider` or
    /// `type=hotkey` is that input, and a `switch` of `type=tick` draws a tick. A block of a folded kind is retired.
    private static func drawn(_ block: TextBlock) -> TextBlock {
        guard let first = block.fields.first else { return block }
        func renamed(_ kind: String, adding extra: [TextBlock.Field] = []) -> TextBlock {
            let rest = block.fields.dropFirst().filter { !($0.key == "look" && $0.value == "tick") }
            return TextBlock(fields: [.init(key: kind, value: first.value)] + rest + extra, firstLine: block.firstLine, children: block.children)
        }
        if foldedKinds.contains(first.key) { return renamed(retired) }
        switch (first.key, block.value("type")) {
        case ("graph", _) where block.values("value").count == 1 && block.value("max") == nil: return renamed("gauge")
        case ("field", "slider"): return renamed("slider")
        case ("field", "hotkey"): return renamed("hotkey")
        case ("switch", "tick"): return renamed("switch", adding: [.init(key: "look", value: "tick")])
        default: return renamed(first.key)
        }
    }

    private init(blocks: [TextBlock], checks: Bool) {
        let blocks = Self.grouping(blocks)
        self.blocks = blocks
        self.checks = checks
        isPicture = blocks.contains { block in block.fields.first.map { Self.isKind($0.key) } ?? false }
        var runs = Set<String>()
        let head = blocks.first { block in block.fields.first.map { !Self.isKind($0.key) } ?? false }
        let repeats = blocks.filter { $0.fields.first?.key == Self.repeatKind }
        let repeated = repeats.first.flatMap { block in block.value(Self.repeatKind).map { (block, $0) } }
        if let (block, _) = repeated { drawing = RepeatDrawing(block: block) }
        let drawn = head.flatMap { SheetLayout(block: $0) }
        let carded = Set(CardFace(head: head, parts: []).drawings.values.flatMap { $0.joined() })
        for block in blocks {
            let kind = block.fields.first?.key
            if kind == Self.repeatKind { continue }
            if let kind, Self.retiredKinds.contains(kind) {
                errors.append(block.firstLine)
            } else if kind == Self.button, let id = block.value(Self.button), drawn?.areas[id] == nil, !carded.contains(id) {
                take(action: id, block)
            } else if kind == "row" {
                rows.append(block)
                if let item = SpotItem(block: block) {
                    if runs.insert(item.run).inserted { items.append(item) }
                } else {
                    errors.append(block.firstLine)
                }
            } else if let kind, SpotPart.kinds.contains(kind), let part = SpotPart(block: block) {
                if Self.formKinds.contains(kind) { fields.append(block) }
                if view == nil, kind == "view" { view = block }
                parts.append(part)
                if checks { checkedFaults += PartCatalog.faults(in: block) }
            } else if summary == nil, block == head {
                summary = block
                take(effects: block)
            } else {
                errors.append(block.firstLine)
            }
        }
        let repeating = repeated.map { (area: $0.1, perLine: drawing.perLine ?? drawing.columns) }
            ?? (!rows.isEmpty && !parts.isEmpty ? (area: Self.rowsArea, perLine: 1) : nil)
        let layout = SheetLayout(block: head, repeating: repeating, repeats: repeats.count)
            ?? repeating.map { SheetLayout(flat: parts, repeating: $0) }
        self.layout = layout
        parts = parts.map { $0.drawn(in: layout) }
        face = CardFace(head: head, parts: parts)
        let values = blocks.filter { Self.valueKinds.contains($0.fields.first?.key ?? "") }
        if let id = head?.value("main") {
            value = values.first { $0.fields.first?.value == id }
            if value == nil, checks { checkedFaults.append("the head names \(id) as main, which no text, number, gauge, graph, switch or slider has") }
        } else if values.count == 1 {
            value = values.first
        }
        if checks { check(head: head) }
        if checks { check(layout: layout) }
    }

    /// This output without the blocks it was read from, so that an answer that is kept holds its rows once, as its items.
    /// It has no rows for a metric and no part faults.
    public func withoutBlocks() -> SpotOutput {
        var output = self
        output.blocks = []
        output.rows = []
        return output
    }

    /// What is wrong with its parts, found by a reading of the same blocks that checks each part.
    public var partFaults: [String] {
        checks ? checkedFaults : SpotOutput(blocks: blocks, checks: true).checkedFaults
    }

    /// Finds what is wrong with the places of the head and the card drawings.
    private mutating func check(head: TextBlock?) {
        for field in head?.fields ?? [] where field.key.hasPrefix("grid.") && !CardFace.places.contains(String(field.key.dropFirst(5))) {
            checkedFaults.append("the head draws \(field.key), which is not a place")
        }
        for drawing in face.drawings.values {
            for id in Set(drawing.joined()) where id != SheetLayout.empty && !parts.contains(where: { $0.id == id }) {
                checkedFaults.append("the card drawing names \(id), which no component has")
            }
        }
    }

    /// Finds what is wrong with the names of the parts and the sheet they make. A part that only a card drawing places is
    /// drawn only on the card, so the sheet's drawing need not place it.
    private mutating func check(layout: SheetLayout?) {
        for id in [Self.reserved] + Self.defaults + takenDefaults where parts.contains(where: { $0.id == id }) {
            checkedFaults.append("a part cannot be called \(id)")
        }
        for id in Self.inputKeys where parts.contains(where: { $0.id == id }) {
            checkedFaults.append("a part cannot be called \(id), which stdin uses")
        }
        for row in rows {
            if row.value("as") != nil {
                checkedFaults.append("the row \(row.value("row") ?? "") has as=, which Openspot no longer reads. A row draws its own keys")
            }
            if let file = row.value("file"), !file.hasPrefix("/") {
                checkedFaults.append("the row \(row.value("row") ?? "") names the file \(file), which does not start with /")
            }
        }
        let carded = Set(face.drawings.values.flatMap { $0.joined() })
        let sheet = parts.filter { !carded.contains($0.id) || layout?.areas[$0.id] != nil }
        if !sheet.isEmpty { checkedFaults += SheetFaults.of(layout: layout, summary: summary, parts: sheet) }
    }

    /// The one switch or slider that is all the output, which the card draws and changes (protocol: The main block and the card).
    public var control: SpotPart? {
        guard items.isEmpty, actions.isEmpty, parts.count == 1, let part = parts.first else { return nil }
        return part.kind == "switch" || part.kind == "slider" ? part : nil
    }

    /// The value when it is a `text`, `number`, `gauge` or `graph`, which a widget and the menu bar show.
    public var metric: TextBlock? {
        ["text", "number", "gauge", "graph"].contains(value?.fields.first?.key ?? "") ? value : nil
    }

    /// The part of a running call that is done, from 0 to 1, from `progress` in the head (protocol: Frames).
    public var progress: Double? {
        summary?.number("progress").map { min(max($0, 0), 1) }
    }

    /// Whether this frame only marks the start or the end of a call of a staying script, or holds nothing, so that a person
    /// who reads the frames needs not see it (protocol: Modes).
    public var isMark: Bool {
        !isPicture && blocks.allSatisfy { $0.fields.allSatisfy { ["call", "end"].contains($0.key) } }
    }

    /// This frame with no effects, so that a head that is taken again acts none of them twice.
    public func withoutEffects() -> SpotOutput {
        var output = self
        output.toast = nil
        output.link = nil
        output.select = nil
        output.ends = []
        output.start = nil
        return output
    }

    /// The rows that answer a text of the main search, or one card in their place when the head draws a `strip` or a `large`
    /// card and the main block has a `value`, which a press sends (protocol: Places).
    public var answers: [SpotItem] {
        guard face.answerSize != nil, let value, let run = value.value("value") else { return items }
        let title = value.value("display") ?? run
        return [SpotItem(title: title, run: run, card: SpotState(output: self, header: SpotState(title: title)).holding(view))]
    }

    /// The component of the value.
    public var valuePart: SpotPart? {
        value.flatMap { block in parts.first { $0.id == block.fields.first?.value } }
    }

    /// How many rows go on one line, when the script prints a repeat.
    public var perLine: Int? {
        layout?.repeated?.perLine
    }

    /// Whether recent picks sort first, unless it prints `recents=false`.
    public var keepsRecent: Bool {
        summary?.flag("recents") != false
    }

    /// All that is wrong with this output as one sheet of parts.
    public var sheetFaults: [String] {
        (parts.isEmpty && perLine == nil ? ["the sheet has no parts"] : []) + retired + unreadable.map { "cannot read the block that starts: \($0)" } + partFaults
    }

    /// The kind of spot that this output makes.
    public var kind: SpotKind {
        if let control { return control.kind == "switch" ? .toggle : .slider }
        return items.isEmpty && actions.isEmpty && parts.isEmpty ? .launch : .list
    }

    private mutating func take(effects block: TextBlock) {
        toast = block.value("toast") ?? toast
        link = block.value("link") ?? link
        select = block.value("select") ?? select
        if let end = block.value("end") { ends.append(end) }
        start = block.value("call") ?? start
    }

    /// Keeps an action. The `open` action sets the word for Enter, and whether a pick stays in the panel.
    private mutating func take(action id: String, _ block: TextBlock) {
        if checks, id == Self.reserved || ((Self.defaults + takenDefaults).contains(id) && id != "open") { checkedFaults.append("an action cannot be called \(id)") }
        if checks, Self.inputKeys.contains(id) { checkedFaults.append("an action cannot be called \(id), which stdin uses") }
        if id == "open" {
            primary = block.value("title")
            pick = block.flag("close") == false ? .stay : .close
            if block.flag("form") == true {
                pickForm = CommandAction(id: id, title: primary ?? "Open", after: pick == .close ? .close : .stay, isForm: true)
            }
        } else if let action = CommandAction(id: id, block: block) {
            actions.append(action)
        } else if PartCatalog.actionFaults(in: block).isEmpty {
            errors.append(block.firstLine)
        } else if checks {
            checkedFaults += PartCatalog.actionFaults(in: block)
        }
    }
}
