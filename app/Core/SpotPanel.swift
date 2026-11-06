import Foundation

/// The parts of a sheet with what the person has set. Each change takes a new generation, and only the answer to the
/// newest one shows, so that an older answer never replaces a newer state.
public struct SpotPanel: Equatable, Sendable {
    public private(set) var parts: [SpotPart]
    public private(set) var every: TimeInterval?
    public private(set) var generation = 0
    public private(set) var layout: SheetLayout?

    /// Returns nil when a script prints no parts.
    public init?(output: PluginOutput) {
        guard !output.parts.isEmpty else { return nil }
        parts = output.parts
        every = output.every
        layout = output.layout
    }

    /// Where its parts lie.
    public var placement: SheetPlacement {
        SheetPlacement(parts: parts, layout: layout ?? SheetLayout(flat: parts))
    }

    /// All values as one block, for the script to read on its standard input.
    public var values: String {
        TextBlock(fields: parts.compactMap { part in part.value.map { .init(key: part.id, value: $0) } }).text
    }

    /// The keys of its parts, in words for the footer.
    public var hint: String {
        let keys = parts.compactMap { part in part.key.map { "\($0.label) \(part.title ?? part.id.capitalized)" } }
        return (keys + ["Esc Close"]).joined(separator: "   ")
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
        every = output.every
        layout = output.layout
        if let id, let kept, let index = parts.firstIndex(where: { $0.id == id }) { parts[index].set(kept) }
        return true
    }
}
