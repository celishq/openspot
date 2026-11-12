import Foundation

/// Why a read runs: the name of its event, with its value, or a reason with no event. A script gets it as
/// `OPENSPOT_REASON`, and the value as `OPENSPOT_VALUE` (B4).
public struct ReadReason: Equatable, Sendable {
    public static let panel = ReadReason(rawValue: SpotEvent.panelOpen)
    public static let sheet = ReadReason(rawValue: SpotEvent.sheetOpen)
    /// The first read of a script whose events would not read it yet, when something starts to want it (B5).
    public static let want = ReadReason(rawValue: "spot.want")
    public static let change = ReadReason(rawValue: "spot.change")
    public static let preview = ReadReason(rawValue: "spot.preview")

    public let rawValue: String
    public let value: String?
    /// Whether an event with a name gives this reason.
    let isEvent: Bool

    private init(rawValue: String, value: String? = nil) {
        self.rawValue = rawValue
        self.value = value
        isEvent = false
    }

    /// The reason of a read that an event with a name starts.
    init(event name: String, value: String?) {
        rawValue = name
        self.value = value
        isEvent = true
    }

    /// The reason of a read of a clock of that many seconds, or of the first want of a script with no clock.
    static func clock(_ seconds: TimeInterval?) -> ReadReason {
        seconds.map { ReadReason(rawValue: SpotEvent.clockPrefix + String(Int($0))) } ?? want
    }

    /// The reason of a read of a text of the main search, or of the search of its sheet.
    static func text(_ text: String, inSheet: Bool) -> ReadReason {
        ReadReason(rawValue: inSheet ? SpotEvent.sheetText : SpotEvent.searchText, value: text)
    }

    /// Whether a clock, a search or an event gives it, which runs too often to keep a record of.
    var isFrequent: Bool {
        isEvent || self == .want || [SpotEvent.searchText, SpotEvent.sheetText].contains(rawValue) || rawValue.hasPrefix(SpotEvent.clockPrefix)
    }

    /// The variables that carry this reason to a script.
    var variables: [String: String] {
        ["OPENSPOT_REASON": rawValue].merging(value.map { ["OPENSPOT_VALUE": $0] } ?? [:]) { _, new in new }
    }
}
