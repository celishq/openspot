public struct FrameCheck: Equatable, Sendable {
    public static let calls = ["show", Frame.open, "drop", "drag", SpotTimer.call]

    public let output: Frame
    public let partFaults: [String]

    public init(text: String, kinds: [BlockKind] = BlockKind.all, isApp: Bool = false) {
        FrameParses.meter?.add()
        let blocks = Frame.grouping(TextBlock.blocks(in: text))
        let output = Frame(grouped: blocks, kinds: kinds)
        let root = FrameRoot(blocks: blocks, kinds: kinds).block
        let placed = Frame.placed(in: output.tree)
        let listed = blocks.filter { block in
            guard let kind = BlockKind.of(block, in: kinds), let id = block.value(kind.word) else { return false }
            return !placed.contains(id) && !kind.presses && block != output.searchField
        }
        let taken = Self.calls.filter { $0 != "drag" || listed.contains { $0.value(ItemKey.file) != nil } }
        var faults: [String] = []
        for block in blocks {
            if block.fields.first?.key == BlockKind.box {
                faults += BlockKind.faults(in: block, kind: BlockKind(name: BlockKind.box))
                continue
            }
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
                faults += BlockKind.faults(in: block, kind: kind)
                continue
            }
            if taken.contains(id), id != Frame.open { faults.append("an action cannot be called \(id)") }
            if id != Frame.open, CommandAction(id: id, block: block) == nil { faults += BlockKind.actionFaults(in: block) }
        }
        faults += output.tree.faults
        for id in taken where output.parts.contains(where: { $0.id == id }) {
            faults.append("a part cannot be called \(id)")
        }
        if output.tree.isWritten {
            faults += output.tree.sheetFaults(parts: output.parts)
        }
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
}
