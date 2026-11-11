import Foundation

/// The moments and the events when Openspot calls `read`, from three header keys that each hold one type: places in `read`,
/// seconds in `every` and events in `on` (B6). A script with none of these is never read.
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

    /// Reads the `read`, `every` and `on` keys of the header of the spot `name`. Returns nil when it has none, and throws a
    /// fault that names the key of a word of another type (B6).
    public init?(read: String?, every: String?, on: String?, of name: String) throws {
        guard read != nil || every != nil || on != nil else { return nil }
        var moments: [Moment] = []
        for word in Self.words(read) {
            switch word {
            case "panel": moments.append(.panel)
            case "sheet": moments.append(.sheet)
            case let word where Int(word) != nil:
                throw SpotError.fault("\(name) has \(word) in its read, which takes only sheet and panel. Write every=\(word)")
            case let word where SpotEvent.isName(word):
                throw SpotError.fault("\(name) has \(word) in its read, which takes only sheet and panel. Write on=\(word)")
            default:
                throw SpotError.fault("\(name) has an unknown read: \(word). Use sheet or panel")
            }
        }
        if let every {
            guard let seconds = Int(every.trimmingCharacters(in: .whitespaces)), seconds > 0 else {
                throw SpotError.fault("\(name) has an unknown every: \(every). Write a whole number of seconds, such as every=60")
            }
            moments.append(.every(TimeInterval(seconds)))
        }
        for word in Self.words(on) {
            guard SpotEvent.isName(word) else {
                throw SpotError.fault("\(name) has an unknown event in its on: \(word). Write a word with a dot, such as on=music.track, or on=clipboard")
            }
            moments.append(.event(word))
        }
        self.moments = moments
    }

    /// The words of a list split by commas, each with no space around it.
    static func words(_ text: String?) -> [String] {
        text.map { $0.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } } ?? []
    }

    /// The events that it lists in `on`.
    public var events: [String] {
        moments.compactMap { if case .event(let name) = $0 { name } else { nil } }
    }

    public func has(_ moment: Moment) -> Bool {
        moments.contains(moment)
    }

    /// Whether the list names an event.
    public var hasEvent: Bool {
        moments.contains { if case .event = $0 { true } else { false } }
    }

    /// Whether the list names events and nothing else, so that only an event or its first want reads it.
    public var waitsForEvents: Bool {
        hasEvent && moments.allSatisfy { if case .event = $0 { true } else { false } }
    }

    /// The first number in the list.
    public var seconds: TimeInterval? {
        for case .every(let seconds) in moments { return seconds }
        return nil
    }
}
