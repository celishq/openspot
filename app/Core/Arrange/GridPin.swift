import Foundation

public enum GridPin: Equatable, Sendable {
    case pinned(GridCell)
    case onGrid
    case full
    case unknown
}
