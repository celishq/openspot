import Foundation

/// The panel of the grid that a spot lies in: the center one, which holds the search, or a side panel left or right of it.
public enum SpotSide: String, CaseIterable, Equatable, Hashable, Sendable {
    case left, center, right
}
