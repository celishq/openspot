import Foundation

/// A place where a sheet shows: the panel, which shows one sheet at a time, a float of its own at the pointer (W7), or a
/// window of its own for a spot that offers one (W10).
public enum SheetPlace: Hashable, Sendable {
    case panel
    case float
    case window

    /// Whether the sheet shows outside the panel, where it stays open after a pick.
    public var isDetached: Bool {
        self != .panel
    }
}
