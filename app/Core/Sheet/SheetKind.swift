import Foundation

public enum SheetKind: Equatable, Sendable {
    case waiting
    case rows
    case parts

    public init(parts: [SpotPart], showsRows: Bool) {
        self = parts.isEmpty || showsRows ? .rows : .parts
    }

    public var showsField: Bool {
        self == .rows
    }

    public var takesKeys: Bool {
        self != .parts
    }
}
