import CoreGraphics
import Foundation

public struct SheetParts: Equatable, Sendable {
    public struct Nudge: Equatable, Sendable {
        public let step: Int
        public let serial: Int

        public static let rest = Nudge(step: 0, serial: 0)
    }

    public struct MenuOpening: Equatable, Sendable {
        public let part: String
        public let serial: Int
    }

    public private(set) var parts: [SpotPart]
    public private(set) var generation = 0
    public private(set) var answered = 0
    public private(set) var layout: SheetLayout?
    public private(set) var tree: ViewTree
    public private(set) var placement: SheetPlacement
    public private(set) var pictureTimes: [String: Double]
    public private(set) var rows: [[String]]
    private var focusOffsets: [Int] = []
    private var focusLineOffsets: [[Int]] = []
    public private(set) var selected: String?
    public private(set) var top: SheetTop

    public init?(output: Frame) {
        guard !output.parts.isEmpty else { return nil }
        parts = output.parts
        layout = output.layout
        tree = output.tree
        top = SheetTop(showsRows: output.layout?.repeated != nil, search: output.search, header: 0)
        placement = Self.placement(of: output.parts, in: output.layout, tree: output.tree, room: top.partsRoom)
        pictureTimes = Self.pictureTimes(of: output.parts)
        rows = Self.rows(of: output.parts)
        orderFocus()
    }

    private static func pictureTimes(of parts: [SpotPart]) -> [String: Double] {
        var times: [String: Double] = [:]
        for part in parts {
            if case .image(let path) = part.control { times[path] = PictureFile(path: path).changed }
        }
        return times
    }

    private static func rows(of parts: [SpotPart]) -> [[String]] {
        parts.first { !$0.items.isEmpty }?.items ?? []
    }

    private static func placement(of parts: [SpotPart], in layout: SheetLayout?, tree: ViewTree, room: CGFloat) -> SheetPlacement {
        guard tree.isWritten else { return SheetPlacement(parts: parts, layout: layout ?? SheetLayout(flat: parts), room: room) }
        return SheetPlacement(filling: tree.height(in: SpotTokens.partsWidth, parts: parts).map { min($0, room) } ?? room)
    }

    mutating func place(top: SheetTop? = nil) {
        if let top { self.top = top }
        placement = Self.placement(of: parts, in: layout, tree: tree, room: self.top.partsRoom)
        orderFocus()
    }

    private mutating func orderFocus() {
        if tree.isWritten {
            focusLineOffsets = Self.lines(of: tree, parts: parts)
            focusOffsets = focusLineOffsets.flatMap { $0 }
            return
        }
        let top = placement.repeatFrame?.maxY ?? -.infinity
        let placed: [(offset: Int, rect: CGRect)] = parts.indices.compactMap { offset in
            let part = parts[offset]
            guard part.isFocusable, let rect = placement.frames[part.id]?.rect, rect.minY >= top else { return nil }
            return (offset, rect)
        }
        let sorted = placed.sorted { $0.rect.minY == $1.rect.minY ? $0.rect.minX < $1.rect.minX : $0.rect.minY < $1.rect.minY }
        focusOffsets = sorted.map(\.offset)
        var lines: [[Int]] = []
        var lineTop: CGFloat?
        for (offset, rect) in sorted {
            if rect.minY == lineTop, !lines.isEmpty {
                lines[lines.count - 1].append(offset)
            } else {
                lines.append([offset])
                lineTop = rect.minY
            }
        }
        focusLineOffsets = lines
    }

    private static func lines(of tree: ViewTree, parts: [SpotPart]) -> [[Int]] {
        var lines: [[Int]] = []
        var lineRow: String?
        var isBelowItems = !tree.nodes.values.contains { $0.kind == BlockKind.items }
        func walk(_ ids: [String], row: String?) {
            for id in ids {
                guard let node = tree.node(id) else { continue }
                if node.kind == BlockKind.items {
                    isBelowItems = true
                    lineRow = nil
                    continue
                }
                if isBelowItems, let offset = parts.firstIndex(where: { $0.id == id }), parts[offset].isFocusable {
                    if let row, row == lineRow, !lines.isEmpty {
                        lines[lines.count - 1].append(offset)
                    } else {
                        lines.append([offset])
                        lineRow = row
                    }
                }
                walk(node.children, row: node.style.resolved(for: [.sheet]).arrangement == .row ? id : row)
            }
        }
        walk(tree.children, row: nil)
        return lines
    }

    public var inputs: [TextBlock.Field] {
        parts.compactMap { part in part.value.map { .init(key: part.id, value: $0) } }
    }

    public var hint: String {
        hint(stopping: { _ in false })
    }

    public func hint(escape: String = "Close", stopping isRunning: (SpotPart) -> Bool, actions: Bool = false) -> String {
        let keys = parts.compactMap { part in part.key.map { "\($0.label) \(isRunning(part) ? "Stop" : part.title ?? part.id.capitalized)" } }
        if actions { return (keys + ["\(ActionMenu.key) Actions"]).joined(separator: "   ") }
        let close = parts.contains { $0.key == ActionKey(name: "escape") } ? [] : ["Esc \(escape)"]
        return (keys + close).joined(separator: "   ")
    }

    public var drawsKeys: Bool {
        parts.contains { part in part.key != nil && layout?.areas[part.id] != nil }
    }

    public var showsRows: Bool {
        layout?.repeated != nil
    }

    public var kind: SheetKind {
        SheetKind(parts: parts, layout: layout)
    }

    public var takesArrows: Bool {
        !showsRows && !focusOffsets.isEmpty
    }

    public var scrollsByArrows: Bool {
        !showsRows && focusOffsets.isEmpty
    }

    public var focusOrder: [SpotPart] {
        focusOffsets.map { parts[$0] }
    }

    private var focusLines: [[SpotPart]] {
        focusLineOffsets.map { $0.map { parts[$0] } }
    }

    public func keepsIconColumn(_ part: SpotPart) -> Bool {
        layout?.isDrawn != true && !part.isSection && part.symbol == nil && !part.fillsHeight
            && parts.contains { !$0.isSection && $0.symbol != nil }
    }

    public var selectedPart: SpotPart? {
        if let selected, let offset = focusOffsets.first(where: { parts[$0].id == selected }) { return parts[offset] }
        guard takesArrows else { return nil }
        return (focusOffsets.first { parts[$0].isEditable } ?? focusOffsets.first).map { parts[$0] }
    }

    public mutating func move(by step: Int) {
        guard let current = selectedPart, let line = focusLines.first(where: { $0.contains { $0.id == current.id } }),
              let index = line.firstIndex(where: { $0.id == current.id })
        else { return }
        selected = line[min(max(index + step, 0), line.count - 1)].id
    }

    @discardableResult
    public mutating func moveLine(by lines: Int) -> Bool {
        guard let current = selectedPart else { return false }
        let all = focusLines
        guard let index = all.firstIndex(where: { $0.contains { $0.id == current.id } }) else { return false }
        if index + lines < 0, showsRows {
            selected = nil
            return true
        }
        let target = min(max(index + lines, 0), all.count - 1)
        guard target != index else { return false }
        let next: SpotPart?
        if let from = placement.frames[current.id]?.rect {
            next = all[target].min { distance($0, from) < distance($1, from) }
        } else {
            let column = all[index].firstIndex { $0.id == current.id } ?? 0
            next = all[target][min(column, all[target].count - 1)]
        }
        guard let next else { return false }
        selected = next.id
        return true
    }

    private func distance(_ part: SpotPart, _ rect: CGRect) -> CGFloat {
        abs((placement.frames[part.id]?.rect.midX ?? 0) - rect.midX)
    }

    @discardableResult
    public mutating func leaveRows() -> Bool {
        guard showsRows, let line = focusLines.first, let first = line.first else { return false }
        selected = first.id
        return true
    }

    public mutating func focus(_ id: String) {
        guard focusOffsets.contains(where: { parts[$0].id == id }) else { return }
        selected = id
    }

    public func differsOnlyInSelection(from other: SheetParts) -> Bool {
        var same = self
        same.selected = other.selected
        return same == other
    }

    public var isSelectionMoved: Bool {
        selected != nil
    }

    public mutating func clearSelection() {
        selected = nil
    }

    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
        return advance()
    }

    @discardableResult
    public mutating func advance() -> Int {
        generation += 1
        return generation
    }

    @discardableResult
    public mutating func take(_ output: Frame, answering generation: Int, keeping id: String? = nil) -> Bool {
        guard generation == self.generation, !output.parts.isEmpty else { return false }
        let kept = parts.first { $0.id == id }?.value
        parts = output.parts
        layout = output.layout
        tree = output.tree
        if let id, let kept, let index = parts.firstIndex(where: { $0.id == id }) { parts[index].set(kept) }
        pictureTimes = Self.pictureTimes(of: parts)
        rows = Self.rows(of: parts)
        place()
        answered = generation
        return true
    }
}
