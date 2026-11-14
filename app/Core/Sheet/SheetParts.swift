import CoreGraphics
import Foundation

/// The parts of a sheet with what the person has set. Each change takes a new generation, and only the answer to the
/// newest one shows, so that an older answer never replaces a newer state.
public struct SheetParts: Equatable, Sendable {
    /// One press of an arrow that asks the sheet to scroll by a row. A new press takes the next serial.
    public struct Nudge: Equatable, Sendable {
        public let step: Int
        public let serial: Int

        /// No press yet.
        public static let rest = Nudge(step: 0, serial: 0)
    }

    /// One press of return that asks the menu of a part to open. A new press takes the next serial.
    public struct MenuOpening: Equatable, Sendable {
        public let part: String
        public let serial: Int
    }

    public private(set) var parts: [SpotPart]
    public private(set) var generation = 0
    public private(set) var layout: SheetLayout?
    /// Where its parts lie, worked out once for each change of its parts.
    public private(set) var placement: SheetPlacement
    private var selected: String?

    /// Returns nil when a script prints no parts.
    public init?(output: SpotOutput) {
        guard !output.parts.isEmpty else { return nil }
        parts = output.parts
        layout = output.layout
        placement = Self.placement(of: output.parts, in: output.layout)
    }

    private static func placement(of parts: [SpotPart], in layout: SheetLayout?) -> SheetPlacement {
        SheetPlacement(parts: parts, layout: layout ?? SheetLayout(flat: parts))
    }

    private mutating func place() {
        placement = Self.placement(of: parts, in: layout)
    }

    /// All values as one block, for the script to read on its standard input.
    public var values: String {
        TextBlock(fields: parts.compactMap { part in part.value.map { .init(key: part.id, value: $0) } }).text
    }

    /// The keys of its parts, in words for the footer.
    public var hint: String {
        hint(stopping: { _ in false })
    }

    /// The keys of its parts, in words for the footer, and last the key of the actions menu when it has `actions`, or else
    /// Esc. The key of a running part says that it stops the call.
    public func hint(stopping isRunning: (SpotPart) -> Bool, actions: Bool = false) -> String {
        let keys = parts.compactMap { part in part.key.map { "\($0.label) \(isRunning(part) ? "Stop" : part.title ?? part.id.capitalized)" } }
        if actions { return (keys + ["\(ActionMenu.key) Actions"]).joined(separator: "   ") }
        let close = parts.contains { $0.key == ActionKey(name: "escape") } ? [] : ["Esc Close"]
        return (keys + close).joined(separator: "   ")
    }

    /// Whether its drawing places a button with a key, so that the footer shows the keys of its parts also beside rows.
    public var drawsKeys: Bool {
        parts.contains { part in part.key != nil && layout?.areas[part.id] != nil }
    }

    /// Whether it draws the rows of the script in one of its areas, so that the search field and the arrows go to them.
    public var showsRows: Bool {
        layout?.repeated != nil
    }

    public var kind: SheetKind {
        SheetKind(parts: parts, layout: layout)
    }

    /// Whether the arrows move the focus among its parts. A sheet of rows leaves them to the rows, until the person moves
    /// past the last row.
    public var takesArrows: Bool {
        !showsRows && !focusOrder.isEmpty
    }

    /// Whether the up and down keys scroll it: it has no part to focus and no rows.
    public var scrollsByArrows: Bool {
        !showsRows && focusOrder.isEmpty
    }

    /// The parts that take the focus, in the order they are drawn: line by line, and left to right on a line. A part that
    /// no drawing places, such as an action, takes none. In a sheet of rows, only the parts below the rows do.
    public var focusOrder: [SpotPart] {
        let top = placement.repeatFrame?.maxY ?? -.infinity
        let placed: [(part: SpotPart, rect: CGRect)] = parts.compactMap { part in
            guard part.isFocusable, let rect = placement.frames[part.id]?.rect, rect.minY >= top else { return nil }
            return (part, rect)
        }
        return placed
            .sorted { $0.rect.minY == $1.rect.minY ? $0.rect.minX < $1.rect.minX : $0.rect.minY < $1.rect.minY }
            .map(\.part)
    }

    /// The focusable parts in lines of the same top, from the top line down.
    private var focusLines: [[SpotPart]] {
        var lines: [[SpotPart]] = []
        var top: CGFloat?
        for part in focusOrder {
            let minY = placement.frames[part.id]?.rect.minY
            if minY == top, !lines.isEmpty {
                lines[lines.count - 1].append(part)
            } else {
                lines.append([part])
                top = minY
            }
        }
        return lines
    }

    /// Whether a part with no icon keeps an empty icon column, so that its words line up with the lines that have one. Only a
    /// line in a sheet with no drawing does, and only when another line there has an icon.
    public func keepsIconColumn(_ part: SpotPart) -> Bool {
        layout?.isDrawn != true && !part.isSection && part.symbol == nil && !part.fillsHeight
            && parts.contains { !$0.isSection && $0.symbol != nil }
    }

    /// The part that has the focus: the one the person moved to, or else the first field, or else the first part. In a sheet
    /// of rows, a part has it only once the person moved to it.
    public var selectedPart: SpotPart? {
        let order = focusOrder
        if let part = order.first(where: { $0.id == selected }) { return part }
        guard takesArrows else { return nil }
        return order.first(where: \.isEditable) ?? order.first
    }

    /// Moves the focus along its line, and stops at either end.
    public mutating func move(by step: Int) {
        guard let current = selectedPart, let line = focusLines.first(where: { $0.contains { $0.id == current.id } }),
              let index = line.firstIndex(where: { $0.id == current.id })
        else { return }
        selected = line[min(max(index + step, 0), line.count - 1)].id
    }

    /// Moves the focus to the part on the line above or below that lies closest across, the left one on a tie. The first
    /// and the last line stop the move, except that a sheet of rows gives the focus back to its rows above its first line.
    /// Returns whether the focus moved.
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

    /// Gives the focus to the first part below its rows. Returns false when no part lies there.
    @discardableResult
    public mutating func leaveRows() -> Bool {
        guard showsRows, let line = focusLines.first, let first = line.first else { return false }
        selected = first.id
        return true
    }

    /// Gives the focus to a part, as a click into its field does.
    public mutating func focus(_ id: String) {
        guard focusOrder.contains(where: { $0.id == id }) else { return }
        selected = id
    }

    /// Whether it holds the same parts and state as another, and differs at most in the selected part.
    public func differsOnlyInSelection(from other: SheetParts) -> Bool {
        var same = self
        same.selected = other.selected
        return same == other
    }

    /// Whether the person moved the selection, so that a clear has something to change.
    public var isSelectionMoved: Bool {
        selected != nil
    }

    public mutating func clearSelection() {
        selected = nil
    }

    /// Takes a value that the person set, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
        return advance()
    }

    /// Starts a new generation, which outdates each call under way.
    @discardableResult
    public mutating func advance() -> Int {
        generation += 1
        return generation
    }

    /// Takes the answer to a call, unless a newer change has outdated it. `keeping` names a part whose text the person
    /// owns while they type. Returns whether it took the answer.
    @discardableResult
    public mutating func take(_ output: SpotOutput, answering generation: Int, keeping id: String? = nil) -> Bool {
        guard generation == self.generation, !output.parts.isEmpty else { return false }
        let kept = parts.first { $0.id == id }?.value
        parts = output.parts
        layout = output.layout
        if let id, let kept, let index = parts.firstIndex(where: { $0.id == id }) { parts[index].set(kept) }
        place()
        return true
    }
}
