import Foundation

/// A moment that selects the spots to read (B1): the open of the panel, the wake of the Mac, or a text of the main search,
/// which each spot whose `answers` pattern matches it answers (A2).
public enum SpotEvent: Equatable, Sendable {
    case panel
    case wake
    case query(String)
}
