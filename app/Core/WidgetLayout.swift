import Foundation

/// A fixed arrangement of places in a widget, on a grid of four columns. Its slots set the size of the widget.
public struct WidgetLayout: Equatable, Sendable {
    /// The cells of the grid that one place takes.
    public struct Slot: Equatable, Sendable {
        public let column: Int
        public let row: Int
        public let columns: Int
        public let rows: Int

        init(_ column: Int, _ row: Int, _ columns: Int, _ rows: Int) {
            self.column = column
            self.row = row
            self.columns = columns
            self.rows = rows
        }
    }

    public let name: String
    public let size: SpotSize
    public let slots: [Slot]

    public static let hero = WidgetLayout(name: "hero", size: .large, slots: [Slot(0, 0, 2, 2), Slot(2, 0, 1, 1), Slot(3, 0, 1, 1), Slot(2, 1, 2, 1)])
    public static let quad = WidgetLayout(name: "quad", size: .large, slots: [Slot(0, 0, 2, 1), Slot(2, 0, 2, 1), Slot(0, 1, 2, 1), Slot(2, 1, 2, 1)])
    public static let pair = WidgetLayout(name: "pair", size: .strip, slots: [Slot(0, 0, 2, 1), Slot(2, 0, 2, 1)])
    public static let row = WidgetLayout(name: "row", size: .strip, slots: [Slot(0, 0, 1, 1), Slot(1, 0, 1, 1), Slot(2, 0, 1, 1), Slot(3, 0, 1, 1)])
    public static let all = [hero, quad, pair, row]

    public init?(name: String) {
        guard let layout = Self.all.first(where: { $0.name == name }) else { return nil }
        self = layout
    }

    private init(name: String, size: SpotSize, slots: [Slot]) {
        self.name = name
        self.size = size
        self.slots = slots
    }
}
