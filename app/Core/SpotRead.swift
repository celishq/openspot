import Foundation

/// When Openspot calls a script with no arguments to see what it prints. A script with none of these is never read.
public enum SpotRead: Equatable, Sendable {
    case click
    case open
    case every(TimeInterval)

    /// Reads the value of a `read` header line: click, open or a number of seconds.
    public init?(name: String) {
        switch name {
        case "click": self = .click
        case "open": self = .open
        default:
            guard let seconds = Int(name), seconds > 0 else { return nil }
            self = .every(TimeInterval(seconds))
        }
    }
}
