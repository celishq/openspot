import Foundation

public enum GridPush: Equatable, Sendable {
    case pushed(off: [String])
    case tooLarge
    case unknown
}
