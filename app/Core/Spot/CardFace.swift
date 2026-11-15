import Foundation

public struct CardFace: Equatable, Sendable {
    public static let places = ["small", "wide", "square", "strip", "large"]

    public private(set) var drawings: [String: [[String]]]
    public private(set) var parts: [SpotPart]
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

    public init(head: TextBlock?, parts: [SpotPart]) {
        var drawings: [String: [[String]]] = [:]
        for field in head?.fields ?? [] where field.key.hasPrefix("grid.") && !field.value.isEmpty {
            let place = String(field.key.dropFirst(5))
            guard Self.places.contains(place) else { continue }
            drawings[place, default: []].append(field.value.split(whereSeparator: \.isWhitespace).map(String.init))
        }
        self.init(drawings: drawings, parts: drawings.isEmpty ? parts.filter { $0.kind == "view" } : parts)
    }

    public func drawing(for size: SpotSize) -> [[String]]? {
        let fitting = SpotSize.all.filter { $0.columns <= size.columns && $0.rows <= size.rows }
        return fitting.reversed().lazy.compactMap { drawings[$0.name] }.first
    }

    public func layout(for size: SpotSize) -> WidgetLayout? {
        layouts[size.name]
    }

    public var answerSize: SpotSize? {
        [SpotSize.large, .strip].first { drawings[$0.name] != nil }
    }

    public var hasView: Bool {
        parts.contains { $0.kind == "view" }
    }

    public mutating func set(_ value: String, of id: String) {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
    }
}
