public struct FrameCheck: Equatable, Sendable {
    public static let calls = ["show", SpotOutput.open, "drop", "drag"]

    public let output: SpotOutput
    public let partFaults: [String]

    public init(text: String, kinds: [BlockKind] = BlockKind.all) {
        FrameParses.meter?.add()
        let blocks = SpotOutput.grouping(TextBlock.blocks(in: text))
        let output = SpotOutput(grouped: blocks, kinds: kinds)
        let rows = blocks.filter { $0.fields.first?.key == BlockKind.row }
        let taken = Self.calls.filter { $0 != "drag" || rows.contains { $0.value(RowKey.file) != nil } }
        let head = FrameHead(blocks: blocks, kinds: kinds).block
        let placed = SpotOutput.placed(by: head)
        var faults: [String] = []
        for block in blocks {
            guard let kind = BlockKind.of(block, in: kinds), let id = block.value(kind.word) else { continue }
            guard kind.presses, !placed.contains(id) else {
                faults += PartCatalog.faults(in: block, kind: kind)
                if kind.isOpen, block.value(BlockKind.row) != nil { faults.append("the view \(id) has the key `row`, which starts a row block. Give the key another name.") }
                continue
            }
            if taken.contains(id), id != SpotOutput.open { faults.append("an action cannot be called \(id)") }
            if id != SpotOutput.open, CommandAction(id: id, block: block) == nil { faults += PartCatalog.actionFaults(in: block) }
        }
        if let id = head?.value(HeadKey.main), output.value == nil {
            faults.append("the head names \(id) as main, which no text, number, gauge, graph, switch or slider has")
        }
        faults += Self.headFaults(head, of: output)
        for id in taken where output.parts.contains(where: { $0.id == id }) {
            faults.append("a part cannot be called \(id)")
        }
        for row in rows {
            if let file = row.value(RowKey.file), !file.hasPrefix("/") {
                faults.append("the row \(row.value(RowKey.row) ?? "") names the file \(file), which does not start with /")
            }
        }
        let carded = Set(output.face.drawings.values.flatMap { $0.joined() })
        let sheet = output.parts.filter { !carded.contains($0.id) || output.layout?.areas[$0.id] != nil }
        if !sheet.isEmpty { faults += SheetFaults.of(layout: output.layout, parts: sheet) }
        var told = Set<String>()
        for field in head?.fields ?? [] where !HeadKey.isKey(field.key) && told.insert(field.key).inserted {
            faults.append("the head has an unknown key: \(field.key)")
        }
        self.output = output
        partFaults = faults
    }

    public var sheetFaults: [String] {
        (output.parts.isEmpty && output.perLine == nil ? ["the sheet has no parts"] : []) + output.errors.map { "cannot read the block that starts: \($0)" } + partFaults
    }

    private static func headFaults(_ head: TextBlock?, of output: SpotOutput) -> [String] {
        var faults: [String] = []
        if let head, head.value(HeadKey.push) != nil || head.value(HeadKey.pushSpot) != nil, head.value(HeadKey.pop) != nil {
            faults.append("the frame holds both push and pop, and moves nothing. Print one of them")
        }
        for field in head?.fields ?? [] where HeaderKey.isDrawing(field.key) && !CardFace.places.contains(String(field.key.dropFirst(HeaderKey.drawing.count))) {
            faults.append("the head draws \(field.key), which is not a place")
        }
        for drawing in output.face.drawings.values {
            for id in Set(drawing.joined()) where id != SheetLayout.empty && !output.parts.contains(where: { $0.id == id }) {
                faults.append("the card drawing names \(id), which no component has")
            }
        }
        return faults
    }
}
