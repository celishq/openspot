import Foundation

public enum NumberLook: Equatable, Sendable {
    case stat
    case ring
    case bar

    init?(type: String) {
        switch type {
        case "ring": self = .ring
        case "bar": self = .bar
        default: return nil
        }
    }
}
