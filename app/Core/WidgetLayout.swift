import Foundation

/// A fixed arrangement of places in a widget, on four columns and its own rows. It sets the size of the widget,
/// except that a single widget can ask for another size.
public struct WidgetLayout: Equatable, Sendable {
    /// How a place shows its metric.
    public enum Form: Equatable, Sendable {
        case big
        case line
        case half
        case stat
        case control
    }

    /// The cells of the grid that one place takes, and the form of the place.
    public struct Slot: Equatable, Sendable {
        public let column: Int
        public let row: Int
        public let columns: Int
        public let rows: Int
        public let form: Form

        init(_ column: Int, _ row: Int, _ columns: Int, _ rows: Int, _ form: Form) {
            self.column = column
            self.row = row
            self.columns = columns
            self.rows = rows
            self.form = form
        }
    }

    public let name: String
    public let size: SpotSize
    public let rows: Int
    public let slots: [Slot]

    public static let single = WidgetLayout(name: "single", size: .square, rows: 1, slots: [Slot(0, 0, 2, 1, .big)])
    public static let hero = WidgetLayout(name: "hero", size: .large, rows: 3, slots: [Slot(0, 0, 2, 3, .big), Slot(2, 0, 2, 1, .line), Slot(2, 1, 2, 1, .line), Slot(2, 2, 2, 1, .line)])
    public static let pair = WidgetLayout(name: "pair", size: .strip, rows: 1, slots: [Slot(0, 0, 2, 1, .half), Slot(2, 0, 2, 1, .half)])
    public static let row = WidgetLayout(name: "row", size: .strip, rows: 1, slots: [Slot(0, 0, 1, 1, .stat), Slot(1, 0, 1, 1, .stat), Slot(2, 0, 1, 1, .stat), Slot(3, 0, 1, 1, .stat)])
    public static let all = [single, hero, pair, row]

    public init?(name: String) {
        guard let layout = Self.all.first(where: { $0.name == name }) else { return nil }
        self = layout
    }

    private init(name: String, size: SpotSize, rows: Int, slots: [Slot]) {
        self.name = name
        self.size = size
        self.rows = rows
        self.slots = slots
    }

    /// The form of a place on a card of this size. A single place follows the card, which the grid may have grown.
    public func form(of slot: Slot, on card: SpotSize) -> Form {
        guard self == .single else { return slot.form }
        if card == .small { return .control }
        return card.rows == 1 ? .half : .big
    }
}
