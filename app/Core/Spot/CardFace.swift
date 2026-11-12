import Foundation

/// What a card draws from its script: a drawing for each size that the script printed with `grid.<size>=`, and the
/// components that the drawings place (protocol: Layouts). A size with no drawing takes the drawing of the nearest smaller size.
public struct CardFace: Equatable, Sendable {
    /// The places a drawing can name, from the smallest card.
    public static let places = ["small", "wide", "square", "strip", "large"]

    public private(set) var drawings: [String: [[String]]]
    public private(set) var parts: [SpotPart]
    /// The drawing of a card of each size, read once, by the name of the size.
    private var layouts: [String: WidgetLayout] = [:]

    public static let none = CardFace(drawings: [:], parts: [])

    public init(drawings: [String: [[String]]], parts: [SpotPart]) {
        self.drawings = drawings
        self.parts = parts
        for size in SpotSize.all {
            guard let drawing = drawing(for: size) else { continue }
            layouts[size.name] = WidgetLayout(drawing: drawing.map { $0.joined(separator: " ") }, size: size)
        }
    }

    /// Reads the `grid.<place>=` lines of a head.
    public init(head: TextBlock?, parts: [SpotPart]) {
        var drawings: [String: [[String]]] = [:]
        for field in head?.fields ?? [] where field.key.hasPrefix("grid.") && !field.value.isEmpty {
            let place = String(field.key.dropFirst(5))
            guard Self.places.contains(place) else { continue }
            drawings[place, default: []].append(field.value.split(whereSeparator: \.isWhitespace).map(String.init))
        }
        self.init(drawings: drawings, parts: drawings.isEmpty ? parts.filter { $0.kind == "view" } : parts)
    }

    /// The drawing for a card of this size: its own, or else the largest that fits in it.
    public func drawing(for size: SpotSize) -> [[String]]? {
        let fitting = SpotSize.all.filter { $0.columns <= size.columns && $0.rows <= size.rows }
        return fitting.reversed().lazy.compactMap { drawings[$0.name] }.first
    }

    /// The drawing for a card of this size, read into places.
    public func layout(for size: SpotSize) -> WidgetLayout? {
        layouts[size.name]
    }

    /// The size of a card that answers the main search: `large` when it draws one, else `strip` when it draws one (protocol: Places).
    public var answerSize: SpotSize? {
        [SpotSize.large, .strip].first { drawings[$0.name] != nil }
    }

    /// Whether a `view` component places the plugin's view, which fills the card when no drawing places it (protocol: Views).
    public var hasView: Bool {
        parts.contains { $0.kind == "view" }
    }

    /// Takes a value that the person set on the card, so that it shows before the script answers.
    public mutating func set(_ value: String, of id: String) {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
    }
}
