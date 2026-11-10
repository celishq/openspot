import Foundation

/// The id of the row of an event or a reminder, which each other verb takes as it is (E1): one time of an event, so that each
/// time of a repeating event has its own, or a reminder.
enum CalendarItemID: Equatable {
    case event(String, start: Date)
    case reminder(String)

    private static let eventPrefix = "event:"
    private static let reminderPrefix = "reminder:"

    /// Reads the id of a row, or returns nil for any other text.
    init?(_ text: String) {
        if text.hasPrefix(Self.reminderPrefix) {
            self = .reminder(String(text.dropFirst(Self.reminderPrefix.count)))
            return
        }
        guard text.hasPrefix(Self.eventPrefix), let slash = text.lastIndex(of: "/"), let seconds = Double(text[text.index(after: slash)...]) else {
            return nil
        }
        self = .event(String(text[text.index(text.startIndex, offsetBy: Self.eventPrefix.count)..<slash]), start: Date(timeIntervalSince1970: seconds))
    }

    var text: String {
        switch self {
        case .event(let id, let start): "\(Self.eventPrefix)\(id)/\(Int(start.timeIntervalSince1970))"
        case .reminder(let id): "\(Self.reminderPrefix)\(id)"
        }
    }

    /// The failure of a verb that got an id that names no row of its kind.
    static func missing(_ text: String) -> PluginError {
        PluginError.failed(1, "Openspot cannot find \(text). Read the list again, and use the id of one of its rows.")
    }
}
