import Foundation

/// A place where a sheet shows: the panel, which shows one sheet at a time, or a float of its own (W7).
public enum SheetPlace: Hashable, Sendable {
    case panel
    case float
}
