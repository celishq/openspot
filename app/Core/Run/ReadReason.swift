import Foundation

/// Why a read runs: a moment of the core, or an event with its value. A script gets it as `OPENSPOT_REASON`, and the value
/// as `OPENSPOT_VALUE` (B4).
public struct ReadReason: Equatable, Sendable {
    public static let panel = ReadReason(rawValue: "panel")
    public static let sheet = ReadReason(rawValue: "sheet")
    public static let timer = ReadReason(rawValue: "timer")
    public static let search = ReadReason(rawValue: "search")
    public static let change = ReadReason(rawValue: "change")

    public let rawValue: String
    public let value: String?
    /// Whether an event with a name gives this reason.
    let isEvent: Bool

    private init(rawValue: String) {
        self.rawValue = rawValue
        value = nil
        isEvent = false
    }

    /// The reason of a read that an event with a name starts.
    init(event name: String, value: String?) {
        rawValue = name
        self.value = value
        isEvent = true
    }

    /// The variables that carry this reason to a script.
    var variables: [String: String] {
        ["OPENSPOT_REASON": rawValue].merging(value.map { ["OPENSPOT_VALUE": $0] } ?? [:]) { _, new in new }
    }
}
