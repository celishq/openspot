import Foundation

public enum GridPin: Equatable, Sendable {
    case pinned(GridCell)
    case pushed(off: [String])
    case onGrid
    case full
    case unknown
}
