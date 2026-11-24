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

    private var shown: [String]
    public private(set) var generation = 0
    public private(set) var answered = 0
    public private(set) var showsRows: Bool
    public private(set) var holdsParts: Bool
    public private(set) var placesSearch: Bool
    public private(set) var tree: ViewTree
    public private(set) var height: CGFloat
    public private(set) var pictureTimes: [String: Double]
    public private(set) var rows: [[String]]
    private var focusLines: [[String]] = []
    private var rowsLine = 0
    public private(set) var selected: String?
    public private(set) var top: SheetTop
    public private(set) var variants: Set<Style.Variant>

    public init(output: Frame, variants: Set<Style.Variant> = [.sheet, .dark]) {
        let every = output.parts
        holdsParts = !every.isEmpty
        shown = holdsParts ? output.tree.partIDs(shownIn: [variants]) : []
        self.variants = variants
        showsRows = output.showsRows
        placesSearch = output.placesSearch
        tree = output.tree
        top = SheetTop(showsRows: showsRows && !placesSearch, search: output.search, header: 0)
        height = 0
        pictureTimes = Self.pictureTimes(of: every)
        rows = output.rows
        place()
    }

    public var parts: [SpotPart] {
        shown.compactMap(part)
    }

    private func part(_ id: String) -> SpotPart? {
        tree.node(id)?.part
    }

    private static func pictureTimes(of parts: [SpotPart]) -> [String: Double] {
        var times: [String: Double] = [:]
        for part in parts {
            if case .image(let path) = part.control { times[path] = PictureFile(path: path).changed }
        }
        return times
    }

    private static func height(of tree: ViewTree, shownIn variants: Set<Style.Variant>, room: CGFloat) -> CGFloat {
        tree.height(in: SpotTokens.partsWidth, variants: variants).map { min($0, room) } ?? room
    }

    mutating func place(top: SheetTop? = nil) {
        if let top { self.top = top }
        height = holdsParts ? Self.height(of: tree, shownIn: variants, room: self.top.partsRoom) : 0
        orderFocus()
    }

    mutating func show(in variants: Set<Style.Variant>) {
        guard variants != self.variants else { return }
        self.variants = variants
        shown = tree.partIDs(shownIn: [variants])
        place()
    }

    private mutating func orderFocus() {
        (focusLines, rowsLine) = Self.lines(of: tree, shown: Set(shown), in: variants)
    }

    private static func lines(of tree: ViewTree, shown: Set<String>, in variants: Set<Style.Variant>) -> ([[String]], Int) {
        var lines: [[String]] = []
        var lineRow: String?
        var rowsLine = 0
        func walk(_ ids: [String], row: String?) {
            for id in ids {
                guard let node = tree.node(id) else { continue }
                if node.kind == .items {
                    rowsLine = lines.count
                    lineRow = nil
                    continue
                }
                if shown.contains(id), node.part?.isFocusable == true {
                    if let row, row == lineRow, !lines.isEmpty {
                        lines[lines.count - 1].append(id)
                    } else {
                        lines.append([id])
                        lineRow = row
                    }
                }
                walk(node.children, row: node.style.resolved(for: variants).arrangement == .row ? id : row)
            }
        }
        walk(tree.children, row: nil)
        return (lines, rowsLine)
    }

    public var inputs: [TextBlock.Field] {
        tree.partIDs(shownIn: Frame.sheetPlaces).compactMap { id in part(id)?.value.map { .init(key: id, value: $0) } }
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

    public var takesArrows: Bool {
        !showsRows && !focusLines.isEmpty
    }

    public var scrollsByArrows: Bool {
        !showsRows && focusLines.isEmpty
    }

    public var focusOrder: [SpotPart] {
        focusLines.joined().compactMap(part)
    }

    public func keepsIconColumn(_ part: SpotPart) -> Bool {
        part.icon == nil && !part.fillsHeight && parts.contains { $0.icon != nil && !$0.fillsHeight }
    }

    public var mainButton: SpotPart? {
        focusOrder.first { part in
            part.isPressable && tree.node(part.id).flatMap { SpotPart.Look(style: $0.style.resolved(for: [.sheet])) } == .strong
        }
    }

    public var selectedPart: SpotPart? {
        let order = focusLines.joined()
        if let selected, order.contains(selected) { return part(selected) }
        guard takesArrows else { return nil }
        return (order.first { part($0)?.isEditable == true } ?? order.first).flatMap(part)
    }

    public mutating func move(by step: Int) {
        guard let current = selectedPart, let line = focusLines.first(where: { $0.contains(current.id) }),
              let index = line.firstIndex(of: current.id)
        else { return }
        selected = line[min(max(index + step, 0), line.count - 1)]
    }

    @discardableResult
    public mutating func moveLine(by lines: Int) -> Bool {
        guard let current = selectedPart else { return false }
        let all = focusLines
        guard let index = all.firstIndex(where: { $0.contains(current.id) }) else { return false }
        if showsRows, (index < rowsLine) != (index + lines < rowsLine) {
            selected = nil
            return true
        }
        let target = min(max(index + lines, 0), all.count - 1)
        guard target != index else { return false }
        let column = all[index].firstIndex(of: current.id) ?? 0
        selected = all[target][min(column, all[target].count - 1)]
        return true
    }

    @discardableResult
    public mutating func leaveRows(upward: Bool = false) -> Bool {
        let all = focusLines
        let target = upward ? rowsLine - 1 : rowsLine
        guard showsRows, all.indices.contains(target), let first = all[target].first else { return false }
        selected = first
        return true
    }

    public mutating func focus(_ id: String) {
        guard focusLines.contains(where: { $0.contains(id) }) else { return }
        selected = id
    }

    public func differsOnlyInSelection(from other: SheetParts) -> Bool {
        var same = self
        same.selected = other.selected
        return same == other
    }

    func changedParts(from other: SheetParts) -> [String]? {
        var same = self
        same.tree = other.tree
        same.generation = other.generation
        guard same == other else { return nil }
        return tree.changedParts(from: other.tree)
    }

    public var isSelectionMoved: Bool {
        selected != nil
    }

    public mutating func clearSelection() {
        selected = nil
    }

    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        tree.set(value, of: id)
        return advance()
    }

    @discardableResult
    public mutating func advance() -> Int {
        generation += 1
        return generation
    }

    @discardableResult
    public mutating func take(_ output: Frame, answering generation: Int, keeping id: String? = nil) -> Bool {
        let every = output.parts
        guard generation == self.generation, !every.isEmpty else { return false }
        let kept = id.flatMap(part)?.value
        showsRows = output.showsRows
        placesSearch = output.placesSearch
        tree = output.tree
        if let id, let kept { tree.set(kept, of: id) }
        shown = tree.partIDs(shownIn: [variants])
        pictureTimes = Self.pictureTimes(of: every)
        rows = output.rows
        place()
        answered = generation
        return true
    }
}
