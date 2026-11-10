import Foundation

/// What kind of sheet a script's answer makes, which says what the search field does: a sheet of rows, a sheet of parts
/// with no rows, or an open sheet that waits for its first answer and cannot say yet.
public enum SheetKind: Equatable, Sendable {
    case waiting
    case rows
    case parts

    /// The kind of an answer with these parts and this drawing: one of rows when it has no parts or its drawing repeats rows.
    public init(parts: [SpotPart], layout: SheetLayout?) {
        self = parts.isEmpty || layout?.repeated != nil ? .rows : .parts
    }

    /// Whether the search field shows. A sheet that waits shows none, so that the answer cannot take it back.
    public var showsField: Bool {
        self == .rows
    }

    /// Whether the search field keeps the keys. A sheet that waits keeps them there, so that what the person types lands.
    public var takesKeys: Bool {
        self != .parts
    }
}
