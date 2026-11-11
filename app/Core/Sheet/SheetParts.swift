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

    public private(set) var parts: [SpotPart]
    public private(set) var generation = 0
    public private(set) var layout: SheetLayout?
    /// Where its parts lie, worked out once for each change of its parts.
    public private(set) var placement: SheetPlacement
    private var selected: String?

    /// Returns nil when a script prints no parts.
    public init?(output: PluginOutput) {
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

    /// The keys of its parts, in words for the footer. The key of a running part says that it stops the call.
    public func hint(stopping isRunning: (SpotPart) -> Bool) -> String {
        let keys = parts.compactMap { part in part.key.map { "\($0.label) \(isRunning(part) ? "Stop" : part.title ?? part.id.capitalized)" } }
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

    /// Whether the up and down keys select its parts. A sheet with a text area or with rows leaves them to those.
    public var takesArrows: Bool {
        !showsRows && !parts.contains(where: \.isEditable) && parts.contains(where: \.isSelectable)
    }

    /// Whether the up and down keys scroll it: it has no part to select, no text area and no rows.
    public var scrollsByArrows: Bool {
        !showsRows && !parts.contains(where: \.isEditable) && !parts.contains(where: \.isSelectable)
    }

    /// Whether a part with no icon keeps an empty icon column, so that its words line up with the lines that have one. Only a
    /// line in a sheet with no drawing does, and only when another line there has an icon.
    public func keepsIconColumn(_ part: SpotPart) -> Bool {
        layout?.isDrawn != true && !part.isSection && part.symbol == nil && !part.fillsHeight
            && parts.contains { !$0.isSection && $0.symbol != nil }
    }

    /// The part that return uses: the one the person moved to, or else the first that takes a selection.
    public var selectedPart: SpotPart? {
        guard takesArrows else { return nil }
        return parts.first { $0.id == selected && $0.isSelectable } ?? parts.first(where: \.isSelectable)
    }

    /// Moves the selection, and stops at the first and last part.
    public mutating func move(by step: Int) {
        let ids = parts.filter(\.isSelectable).map(\.id)
        guard let index = ids.firstIndex(where: { $0 == selectedPart?.id }) else { return }
        selected = ids[min(max(index + step, 0), ids.count - 1)]
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
    public mutating func take(_ output: PluginOutput, answering generation: Int, keeping id: String? = nil) -> Bool {
        guard generation == self.generation, !output.parts.isEmpty else { return false }
        let kept = parts.first { $0.id == id }?.value
        parts = output.parts
        layout = output.layout
        if let id, let kept, let index = parts.firstIndex(where: { $0.id == id }) { parts[index].set(kept) }
        place()
        return true
    }
}
