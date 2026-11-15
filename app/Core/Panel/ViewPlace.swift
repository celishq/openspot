import Foundation

public enum ViewPlace: Equatable, Sendable {
    case card
    case sample
    case sheet(String)
    case detached(String)
}
