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
    public private(set) var layout: SheetLayout?
    public private(set) var placement: SheetPlacement
    public private(set) var pictureTimes: [String: Double]
    private var focusOffsets: [Int] = []
    private var focusLineOffsets: [[Int]] = []
    private var selected: String?

    public init?(output: SpotOutput) {
        guard !output.parts.isEmpty else { return nil }
        parts = output.parts
        layout = output.layout
        placement = Self.placement(of: output.parts, in: output.layout)
        pictureTimes = Self.pictureTimes(of: output.parts)
        orderFocus()
    }

    private static func pictureTimes(of parts: [SpotPart]) -> [String: Double] {
        var times: [String: Double] = [:]
        for part in parts {
            guard case .image(let path) = part.control else { continue }
            times[path] = PictureFile(path: path).changed
        }
        return times
    }

    private static func placement(of parts: [SpotPart], in layout: SheetLayout?) -> SheetPlacement {
        SheetPlacement(parts: parts, layout: layout ?? SheetLayout(flat: parts))
    }

    private mutating func place() {
        placement = Self.placement(of: parts, in: layout)
        orderFocus()
    }

    private mutating func orderFocus() {
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

    public var values: String {
        TextBlock(fields: parts.compactMap { part in part.value.map { .init(key: part.id, value: $0) } }).text
    }

    public var hint: String {
        hint(stopping: { _ in false })
    }

    public func hint(escape: String = "Close", stopping isRunning: (SpotPart) -> Bool) -> String {
        let keys = parts.compactMap { part in part.key.map { "\($0.label) \(isRunning(part) ? "Stop" : part.title ?? part.id.capitalized)" } }
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
        guard let current = selectedPart, let from = placement.frames[current.id]?.rect else { return false }
        let all = focusLines
        guard let index = all.firstIndex(where: { $0.contains { $0.id == current.id } }) else { return false }
        if index + lines < 0, showsRows {
            selected = nil
            return true
        }
        let target = min(max(index + lines, 0), all.count - 1)
        guard target != index, let next = all[target].min(by: { distance($0, from) < distance($1, from) }) else { return false }
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
    public mutating func take(_ output: SpotOutput, answering generation: Int, keeping id: String? = nil) -> Bool {
        guard generation == self.generation, !output.parts.isEmpty else { return false }
        let kept = parts.first { $0.id == id }?.value
        parts = output.parts
        layout = output.layout
        if let id, let kept, let index = parts.firstIndex(where: { $0.id == id }) { parts[index].set(kept) }
        pictureTimes = Self.pictureTimes(of: parts)
        place()
        return true
    }
}
