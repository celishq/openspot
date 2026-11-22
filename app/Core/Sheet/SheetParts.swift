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
    private var every: [SpotPart]
    public private(set) var generation = 0
    public private(set) var answered = 0
    public private(set) var showsRows: Bool
    public private(set) var tree: ViewTree
    public private(set) var height: CGFloat
    public private(set) var pictureTimes: [String: Double]
    public private(set) var rows: [[String]]
    private var focusOffsets: [Int] = []
    private var focusLineOffsets: [[Int]] = []
    public private(set) var selected: String?
    public private(set) var top: SheetTop
    public private(set) var variants: Set<Style.Variant>

    public init?(output: Frame, variants: Set<Style.Variant> = [.sheet, .dark]) {
        guard !output.parts.isEmpty else { return nil }
        every = output.parts
        parts = Self.parts(of: output.parts, in: output.sheet, shownIn: variants)
        self.variants = variants
        showsRows = output.perLine != nil
        tree = output.sheet
        top = SheetTop(showsRows: showsRows, search: output.search, header: 0)
        height = 0
        pictureTimes = Self.pictureTimes(of: output.parts)
        rows = Self.rows(of: output.parts)
        place()
    }

    private static func parts(of every: [SpotPart], in tree: ViewTree, shownIn variants: Set<Style.Variant>) -> [SpotPart] {
        let shown = Set(tree.shown(in: variants))
        return every.filter { shown.contains($0.id) }
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

    private static func height(of parts: [SpotPart], in tree: ViewTree, shownIn variants: Set<Style.Variant>, room: CGFloat) -> CGFloat {
        tree.height(in: SpotTokens.partsWidth, parts: parts, variants: variants).map { min($0, room) } ?? room
    }

    mutating func place(top: SheetTop? = nil) {
        if let top { self.top = top }
        height = Self.height(of: parts, in: tree, shownIn: variants, room: self.top.partsRoom)
        orderFocus()
    }

    mutating func show(in variants: Set<Style.Variant>) {
        guard variants != self.variants else { return }
        self.variants = variants
        parts = Self.parts(of: every, in: tree, shownIn: variants)
        place()
    }

    private mutating func orderFocus() {
        focusLineOffsets = Self.lines(of: tree, parts: parts, in: variants)
        focusOffsets = focusLineOffsets.flatMap { $0 }
    }

    private static func lines(of tree: ViewTree, parts: [SpotPart], in variants: Set<Style.Variant>) -> [[Int]] {
        var lines: [[Int]] = []
        var lineRow: String?
        var isBelowItems = !tree.holdsItems
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
                walk(node.children, row: node.style.resolved(for: variants).arrangement == .row ? id : row)
            }
        }
        walk(tree.children, row: nil)
        return lines
    }

    public var inputs: [TextBlock.Field] {
        every.compactMap { part in part.value.map { .init(key: part.id, value: $0) } }
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
        showsRows && parts.contains { $0.key != nil }
    }

    public var kind: SheetKind {
        SheetKind(parts: parts, showsRows: showsRows)
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
        part.symbol == nil && !part.fillsHeight && parts.contains { $0.symbol != nil }
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
        let column = all[index].firstIndex { $0.id == current.id } ?? 0
        selected = all[target][min(column, all[target].count - 1)].id
        return true
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
        every.firstIndex { $0.id == id }.map { every[$0].set(value) }
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
        let kept = every.first { $0.id == id }?.value
        every = output.parts
        showsRows = output.perLine != nil
        tree = output.sheet
        if let id, let kept, let index = every.firstIndex(where: { $0.id == id }) { every[index].set(kept) }
        parts = Self.parts(of: every, in: tree, shownIn: variants)
        pictureTimes = Self.pictureTimes(of: every)
        rows = Self.rows(of: every)
        place()
        answered = generation
        return true
    }
}
