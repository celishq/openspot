import Foundation

enum CalendarItemID: Equatable {
    case event(String, start: Date)
    case reminder(String)

    private static let eventPrefix = "event:"
    private static let reminderPrefix = "reminder:"

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

    static func missing(_ text: String) -> SpotError {
        SpotError.failed(1, "Openspot cannot find \(text). Read the list again, and use the id of one of its rows.")
    }
}
