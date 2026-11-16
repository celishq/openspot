import Foundation

public enum FirstAnswer: Equatable, Sendable {
    case frame(SpotOutput)
    case ended
    case stopped
}
