public struct FrameCheck: Equatable, Sendable {
    public static let calls = ["show", Frame.open, "drop", "drag", SpotTimer.call]

    public let output: Frame
    public let partFaults: [String]

    public init(text: String, kinds: [BlockKind] = BlockKind.all, isApp: Bool = false) {
        FrameParses.meter?.add()
        let blocks = Frame.grouping(TextBlock.blocks(in: text))
        let output = Frame(grouped: blocks, kinds: kinds)
        let root = FrameRoot(blocks: blocks, kinds: kinds).block
        let placed = Frame.placed(by: root)
        let listed = blocks.filter { block in
            guard let kind = BlockKind.of(block, in: kinds), let id = block.value(kind.word) else { return false }
            return !placed.contains(id) && !kind.presses && kind != .section && block != output.searchField
        }
        let taken = Self.calls.filter { $0 != "drag" || listed.contains { $0.value(ItemKey.file) != nil } }
        var faults: [String] = []
        for block in blocks {
            guard let kind = BlockKind.of(block, in: kinds), let id = block.value(kind.word) else { continue }
            if listed.contains(block) {
                if taken.contains(id) { faults.append("an item cannot be called \(id)") }
                if kind == .hotkey { faults += kind.faults(block) }
                if let file = block.value(ItemKey.file), !file.hasPrefix("/") {
                    faults.append("the item \(id) names the file \(file), which does not start with /")
                }
                continue
            }
            guard kind.presses, !placed.contains(id) else {
                faults += PartCatalog.faults(in: block, kind: kind)
                continue
            }
            if taken.contains(id), id != Frame.open { faults.append("an action cannot be called \(id)") }
            if id != Frame.open, CommandAction(id: id, block: block) == nil { faults += PartCatalog.actionFaults(in: block) }
        }
        faults += Self.rootFaults(root, of: output)
        faults += output.tree.faults
        for id in taken where output.parts.contains(where: { $0.id == id }) {
            faults.append("a part cannot be called \(id)")
        }
        let carded = Set(output.face.drawings.values.flatMap { $0.joined() })
        let sheet = output.parts.filter { !carded.contains($0.id) || output.layout?.areas[$0.id] != nil }
        if !sheet.isEmpty { faults += SheetFaults.of(layout: output.layout, parts: sheet) }
        var told = Set<String>()
        for field in root?.fields ?? [] where !RootKey.isKey(field.key, isApp: isApp) && told.insert(field.key).inserted {
            faults.append("the root has an unknown key: \(field.key)")
        }
        self.output = output
        partFaults = faults
    }

    public var sheetFaults: [String] {
        (output.parts.isEmpty && output.perLine == nil ? ["the sheet has no parts"] : []) + output.errors.map { "cannot read the block that starts: \($0)" } + partFaults
    }

    private static func rootFaults(_ root: TextBlock?, of output: Frame) -> [String] {
        var faults: [String] = []
        for field in root?.fields ?? [] where RootKey.isDrawing(field.key) && !CardFace.places.contains(String(field.key.dropFirst(RootKey.drawing.count))) {
            faults.append("the root draws \(field.key), which is not a place")
        }
        for drawing in output.face.drawings.values {
            for id in Set(drawing.joined()) where id != SheetLayout.empty && !output.face.parts.contains(where: { $0.id == id }) {
                faults.append("the card drawing names \(id), which no component has")
            }
        }
        return faults
    }
}
