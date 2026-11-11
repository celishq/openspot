import Foundation

/// The moments and the events when Openspot calls `read`, which the `read` header line lists. A script with none of these
/// is never read.
public struct SpotRead: Equatable, Sendable {
    public enum Moment: Equatable, Sendable {
        case panel
        case sheet
        case every(TimeInterval)
        case event(String)
    }

    public static let panel = SpotRead(moments: [.panel])
    public static let sheet = SpotRead(moments: [.sheet])

    public let moments: [Moment]

    public init(moments: [Moment]) {
        self.moments = moments
    }

    /// Reads the value of a `read` header line: moments and events split by commas. Returns nil when one word is neither.
    public init?(text: String) {
        var moments: [Moment] = []
        for word in text.split(separator: ",", omittingEmptySubsequences: false).map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch word {
            case "panel": moments.append(.panel)
            case "sheet": moments.append(.sheet)
            case let word where SpotEvent.isName(word): moments.append(.event(word))
            default:
                guard let seconds = Int(word), seconds > 0 else { return nil }
                moments.append(.every(TimeInterval(seconds)))
            }
        }
        self.moments = moments
    }

    public func has(_ moment: Moment) -> Bool {
        moments.contains(moment)
    }

    /// Whether the list names an event.
    public var hasEvent: Bool {
        moments.contains { if case .event = $0 { true } else { false } }
    }

    /// The first number in the list.
    public var seconds: TimeInterval? {
        for case .every(let seconds) in moments { return seconds }
        return nil
    }
}
