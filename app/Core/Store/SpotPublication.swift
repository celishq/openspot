import Foundation

/// Whether the store's package of a spot of the spots folder holds its files as they are, or older ones.
public enum SpotPublication: Equatable, Sendable {
    case current, changed
}
