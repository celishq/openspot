import Foundation

public struct ShowEvents: Equatable, Sendable {
    public enum Moment: Equatable, Sendable {
        case panel
        case sheet
        case every(TimeInterval)
        case event(String)
    }

    public static let panel = ShowEvents(moments: [.panel])
    public static let sheet = ShowEvents(moments: [.sheet])

    public private(set) var moments: [Moment]
    public let answers: AnswerPattern?
    public let searchesSheet: Bool
    private let filters: [String: AnswerPattern]

    public init(moments: [Moment], answers: AnswerPattern? = nil, searchesSheet: Bool = false, filters: [String: AnswerPattern] = [:]) {
        self.moments = moments
        self.answers = answers
        self.searchesSheet = searchesSheet
        self.filters = filters
    }

    public func adding(_ moment: Moment) -> ShowEvents {
        var events = self
        if !has(moment) { events.moments.append(moment) }
        return events
    }

    public var events: [String] {
        moments.compactMap { if case .event(let name) = $0 { name } else { nil } }
    }

    public func has(_ moment: Moment) -> Bool {
        moments.contains(moment)
    }

    public func admits(_ name: String, value: String?) -> Bool {
        guard has(.event(name)) else { return false }
        guard let filter = filters[name] else { return true }
        return filter.matches(value ?? "")
    }

    public var hasEvent: Bool {
        moments.contains { if case .event = $0 { true } else { false } }
    }

    public var waitsForEvents: Bool {
        hasEvent && moments.allSatisfy { if case .event = $0 { true } else { false } }
    }

    public var seconds: TimeInterval? {
        for case .every(let seconds) in moments { return seconds }
        return nil
    }

    public static func == (one: ShowEvents, two: ShowEvents) -> Bool {
        one.moments == two.moments && one.answers == two.answers && one.searchesSheet == two.searchesSheet && one.filters == two.filters
    }
}
