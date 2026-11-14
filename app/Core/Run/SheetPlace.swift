import Foundation

public enum SheetPlace: Hashable, Sendable {
    case panel
    case float
    case window

    public var isDetached: Bool {
        self != .panel
    }
}
