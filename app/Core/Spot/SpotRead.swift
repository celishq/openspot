import Foundation

/// The events that read a script, from the `on=<event> [filter]` lines of its header (protocol: Events): the open of its sheet or of
/// the panel, a clock, a text of the main search or of its sheet, and any other event with a name. A filter is a regular
/// expression that the value of its event must match, and only `search.text`, `app.front`, `app.update` and an event that a spot emits take one.
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
    /// The pattern of the texts of the main search that it answers, from `on=search.text <pattern>` (protocol: Places).
    public let answers: AnswerPattern?
    /// Whether each change of the search of its sheet reads it, from `on=sheet.text`.
    public let searchesSheet: Bool
    private let filters: [String: AnswerPattern]

    public init(moments: [Moment], answers: AnswerPattern? = nil, searchesSheet: Bool = false) {
        self.moments = moments
        self.answers = answers
        self.searchesSheet = searchesSheet
        filters = [:]
    }

    /// Reads the `on` lines of the header of the spot `name`. Returns nil when it has none, and throws a fault that names
    /// the line that it cannot read (protocol: Events).
    public init?(on lines: [String], of name: String) throws {
        guard !lines.isEmpty else { return nil }
        var moments: [Moment] = []
        var answers: AnswerPattern?
        var searchesSheet = false
        var filters: [String: AnswerPattern] = [:]
        for line in lines {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            let event = parts.first.map(String.init) ?? ""
            let filterText = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
            var filter: AnswerPattern?
            if let filterText {
                guard let pattern = AnswerPattern(filterText) else {
                    throw SpotError.fault("\(name) has an unknown filter in on=\(line). Write a regular expression after the event, such as on=search.text ^[0-9]")
                }
                filter = pattern
            }
            if filter != nil, [SpotEvent.sheetOpen, SpotEvent.panelOpen, SpotEvent.sheetText, SpotEvent.clipboard, SpotEvent.screenWake].contains(event) || event.hasPrefix(SpotEvent.clockPrefix) {
                throw SpotError.fault("\(name) has a filter in on=\(line), and \(event) takes none. Write on=\(event) alone. A filter follows only an event with a value, such as on=app.front com\\.apple\\.Notes")
            }
            switch event {
            case SpotEvent.sheetOpen: moments.append(.sheet)
            case SpotEvent.panelOpen: moments.append(.panel)
            case SpotEvent.sheetText:
                searchesSheet = true
                if !moments.contains(.sheet) { moments.append(.sheet) }
            case SpotEvent.searchText:
                guard let filter else {
                    throw SpotError.fault("\(name) needs a pattern of the texts that it answers, such as on=search.text ^[0-9]")
                }
                answers = filter
            case let word where word.hasPrefix(SpotEvent.clockPrefix):
                guard let seconds = Int(word.dropFirst(SpotEvent.clockPrefix.count)), seconds > 0 else {
                    throw SpotError.fault("\(name) has an unknown clock: \(word). Write a whole number of seconds, such as on=clock.60")
                }
                moments.append(.every(TimeInterval(seconds)))
            case let word where SpotEvent.isName(word):
                moments.append(.event(word))
                if let filter { filters[word] = filter }
            default:
                throw SpotError.fault("\(name) has an unknown event in on=\(line). Write a word with a dot, such as on=sheet.open or on=music.track")
            }
        }
        self.moments = moments
        self.answers = answers
        self.searchesSheet = searchesSheet
        self.filters = filters
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

    /// Whether it lists the event, and the filter of the event, if any, matches the value.
    public func admits(_ name: String, value: String?) -> Bool {
        guard has(.event(name)) else { return false }
        guard let filter = filters[name] else { return true }
        return filter.matches(value ?? "")
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

    public static func == (one: SpotRead, two: SpotRead) -> Bool {
        one.moments == two.moments && one.answers == two.answers && one.searchesSheet == two.searchesSheet && one.filters == two.filters
    }
}
