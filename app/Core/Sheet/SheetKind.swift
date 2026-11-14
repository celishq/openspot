import Foundation

public enum SheetKind: Equatable, Sendable {
    case waiting
    case rows
    case parts

    public init(parts: [SpotPart], layout: SheetLayout?) {
        self = parts.isEmpty || layout?.repeated != nil ? .rows : .parts
    }

    public var showsField: Bool {
        self == .rows
    }

    public var takesKeys: Bool {
        self != .parts
    }
}
