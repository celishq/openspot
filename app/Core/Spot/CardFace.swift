import Foundation

public struct CardFace: Equatable, Sendable {
    public static let bar = "bar"
    public static let places = SpotSize.all.map(\.name) + [bar]

    public private(set) var drawings: [String: [[String]]]
    public private(set) var parts: [SpotPart]
    public private(set) var tree = ViewTree.empty
    private var layouts: [String: CardLayout] = [:]

    public static let none = CardFace(drawings: [:], parts: [])

    public init(drawings: [String: [[String]]], parts: [SpotPart], tree: ViewTree = .empty) {
        self.drawings = drawings
        self.parts = parts
        self.tree = tree
        for size in SpotSize.all {
            guard let drawing = drawing(for: size) else { continue }
            layouts[size.name] = CardLayout(drawing: drawing.map { $0.joined(separator: " ") }, size: size)
        }
    }

    public init(head: TextBlock?, parts: [SpotPart], tree: ViewTree = .empty) {
        var drawings: [String: [[String]]] = [:]
        for field in head?.fields ?? [] where RootKey.isDrawing(field.key) && !field.value.isEmpty {
            let place = String(field.key.dropFirst(RootKey.drawing.count))
            guard Self.places.contains(place) else { continue }
            drawings[place, default: []].append(field.value.split(whereSeparator: \.isWhitespace).map(String.init))
        }
        self.init(drawings: drawings, parts: drawings.isEmpty ? parts.filter { $0.isOpen } : parts, tree: tree)
    }

    public func drawing(for size: SpotSize) -> [[String]]? {
        let fitting = SpotSize.all.filter { $0.columns <= size.columns && $0.rows <= size.rows }
        return fitting.reversed().lazy.compactMap { drawings[$0.name] }.first
    }

    public func layout(for size: SpotSize) -> CardLayout? {
        layouts[size.name]
    }

    public var answerSize: SpotSize? {
        [SpotSize.large, .strip].first { size in
            drawings[size.name] != nil || Style.Variant(size: size).map(tree.places.contains) == true
        }
    }

    public var hasView: Bool {
        parts.contains { $0.isOpen }
    }

    public mutating func set(_ value: String, of id: String) {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
    }
}
