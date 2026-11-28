import Foundation

public enum GridTop: Equatable, Sendable {
    case placed(off: [String])
    case tooLarge
    case unknown
}
