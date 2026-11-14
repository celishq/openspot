import Foundation

public struct SpotOutput: Equatable, Sendable {
    public private(set) var summary: TextBlock?
    public private(set) var rows: [TextBlock] = []
    public private(set) var items: [SpotItem] = []
    public private(set) var fields: [TextBlock] = []
    public private(set) var actions: [CommandAction] = []
    public private(set) var openTitle: String?
    public private(set) var pick = ItemPick.close
    public private(set) var pickForm: CommandAction?
    public private(set) var parts: [SpotPart] = []
    public private(set) var errors: [String] = []
    public private(set) var retired: [String] = []
    public private(set) var layout: SheetLayout?
    public private(set) var value: TextBlock?
    public private(set) var view: TextBlock?
    public private(set) var face = CardFace.none
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var toast: String?
    public private(set) var link: String?
    public private(set) var ends: [String] = []
    public private(set) var start: String?
    private var blocks: [TextBlock]
    private let checksParts: Bool
    private var checkedFaults: [String] = []
    public private(set) var select: String?
    public private(set) var move: FlowMove?
    public let isPicture: Bool

    private static let reserved = "read"
    private static let appEvents = ["open", "drop"]

    private var newerEvents: [String] {
        blocks.contains { $0.fields.first?.key == "row" && $0.value("file") != nil } ? ["drag"] : []
    }
    private static let stdinKeys = ["search", "form", "value"]
    private static let button = "button"
    private static let repeatKind = "repeat"
    private static let optionKind = "option"
    private static let retiredKinds: Set<String> = ["template", "spot", retired]
    private static let retired = "retired"
    private static let foldedKinds: Set<String> = ["gauge", "slider", "hotkey"]
    private static let rowsArea = "rows"
    private static let formKinds: Set<String> = ["field", "choice", "switch", "slider"]
    private static let valueKinds: Set<String> = ["text", "number", "gauge", "graph", "switch", "slider"]

    static func isKind(_ key: String) -> Bool {
        key == "row" || key == repeatKind || key == optionKind || retiredKinds.contains(key) || SpotPart.kinds.contains(key)
    }

    private static let headKeys: Set<String> = ["grid", "main", "title", "detail", "active", "recents", "toast", "link", "progress", "select", "push", "push.spot", "push.title", "push.replace", "pop", "end", "call", "search"]

    private static func isHead(_ key: String) -> Bool {
        headKeys.contains(key) || key.hasPrefix("grid.")
    }

    public var webPictures: [String] {
        blocks.flatMap { [$0] + $0.children }.compactMap { $0.value("icon") }.filter(WebPictures.isWeb)
    }

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

    private static func retiredWord(of block: TextBlock) -> String? {
        guard let first = block.fields.first else { return nil }
        switch first.key {
        case "gauge": return "gauge=\(first.value) is now a graph. Write graph=\(first.value) with one value from 0 to 1."
        case "slider", "hotkey": return "\(first.key)=\(first.value) is now a field. Write field=\(first.value) with type=\(first.key)."
        case "row" where block.value("keyword") != nil:
            return "The row \(first.value) has keyword=\(block.value("keyword")!), which Openspot no longer reads. Write keywords=a, b."
        case "switch" where block.value("look") == "tick": return "The switch \(first.value) has look=tick, which Openspot no longer reads. Write type=tick."
        case _ where !isKind(first.key) && block.value("search") == "script":
            return "The head has search=script, which Openspot no longer reads. Write on=sheet.text in the header."
        default: return nil
        }
    }

    var unreadable: [String] {
        errors.filter { line in !Self.foldedKinds.contains(String(line.prefix { $0 != "=" })) }
    }

    static func reading(_ text: String) async -> SpotOutput {
        await Task.detached(priority: .userInitiated) { SpotOutput(text: text) }.value
    }

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
        self.checksParts = checks
        isPicture = blocks.contains { block in block.fields.first.map { Self.isKind($0.key) } ?? false }
        var runs = Set<String>()
        let head = blocks.first { block in block.fields.first.map { Self.isHead($0.key) } ?? false }
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
                if checksParts { checkedFaults += PartCatalog.faults(in: block) }
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
            if value == nil, checksParts { checkedFaults.append("the head names \(id) as main, which no text, number, gauge, graph, switch or slider has") }
        } else if values.count == 1 {
            value = values.first
        }
        if checksParts { check(head: head) }
        if checksParts { check(layout: layout) }
    }

    public func withoutBlocks() -> SpotOutput {
        var output = self
        output.blocks = []
        output.rows = []
        return output
    }

    public var partFaults: [String] {
        checksParts ? checkedFaults : SpotOutput(blocks: blocks, checks: true).checkedFaults
    }

    private mutating func check(head: TextBlock?) {
        if let head, head.value("push") != nil || head.value("push.spot") != nil, head.value("pop") != nil {
            checkedFaults.append("the frame holds both push and pop, and moves nothing. Print one of them")
        }
        for field in head?.fields ?? [] where field.key.hasPrefix("grid.") && !CardFace.places.contains(String(field.key.dropFirst(5))) {
            checkedFaults.append("the head draws \(field.key), which is not a place")
        }
        for drawing in face.drawings.values {
            for id in Set(drawing.joined()) where id != SheetLayout.empty && !parts.contains(where: { $0.id == id }) {
                checkedFaults.append("the card drawing names \(id), which no component has")
            }
        }
    }

    private mutating func check(layout: SheetLayout?) {
        for id in [Self.reserved] + Self.appEvents + newerEvents where parts.contains(where: { $0.id == id }) {
            checkedFaults.append("a part cannot be called \(id)")
        }
        for id in Self.stdinKeys where parts.contains(where: { $0.id == id }) {
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

    public var control: SpotPart? {
        guard items.isEmpty, actions.isEmpty, parts.count == 1, let part = parts.first else { return nil }
        return part.kind == "switch" || part.kind == "slider" ? part : nil
    }

    public var metric: TextBlock? {
        ["text", "number", "gauge", "graph"].contains(value?.fields.first?.key ?? "") ? value : nil
    }

    public var progress: Double? {
        summary?.number("progress").map { min(max($0, 0), 1) }
    }

    public var isMark: Bool {
        !isPicture && blocks.allSatisfy { $0.fields.allSatisfy { ["call", "end"].contains($0.key) } }
    }

    public func withoutEffects() -> SpotOutput {
        var output = self
        output.toast = nil
        output.link = nil
        output.select = nil
        output.move = nil
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
        summary?.value("search") == "off"
    }

    public var keepsRecent: Bool {
        summary?.flag("recents") != false
    }

    public var sheetFaults: [String] {
        (parts.isEmpty && perLine == nil ? ["the sheet has no parts"] : []) + retired + unreadable.map { "cannot read the block that starts: \($0)" } + partFaults
    }

    public var kind: SpotKind {
        if let control { return control.kind == "switch" ? .toggle : .slider }
        return items.isEmpty && actions.isEmpty && parts.isEmpty ? .launch : .list
    }

    private mutating func take(effects block: TextBlock) {
        toast = block.value("toast") ?? toast
        link = block.value("link") ?? link
        select = block.value("select") ?? select
        move = FlowMove(block: block) ?? move
        if let end = block.value("end") { ends.append(end) }
        start = block.value("call") ?? start
    }

    private mutating func take(action id: String, _ block: TextBlock) {
        if checksParts, id == Self.reserved || ((Self.appEvents + newerEvents).contains(id) && id != "open") { checkedFaults.append("an action cannot be called \(id)") }
        if checksParts, Self.stdinKeys.contains(id) { checkedFaults.append("an action cannot be called \(id), which stdin uses") }
        if id == "open" {
            openTitle = block.value("title")
            pick = block.flag("close") == false ? .stay : .close
            if block.flag("form") == true {
                pickForm = CommandAction(id: id, title: openTitle ?? "Open", after: pick == .close ? .close : .stay, isForm: true)
            }
        } else if let action = CommandAction(id: id, block: block) {
            actions.append(action)
        } else if PartCatalog.actionFaults(in: block).isEmpty {
            errors.append(block.firstLine)
        } else if checksParts {
            checkedFaults += PartCatalog.actionFaults(in: block)
        }
    }
}
