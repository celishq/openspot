import Foundation

public struct ReadReason: Equatable, Sendable {
    public static let panel = ReadReason(rawValue: SpotEvent.panelOpen)
    public static let sheet = ReadReason(rawValue: SpotEvent.sheetOpen)
    public static let want = ReadReason(rawValue: "spot.want")
    public static let change = ReadReason(rawValue: "spot.change")
    public static let preview = ReadReason(rawValue: "spot.preview")

    public let rawValue: String
    public let value: String?
    let isEvent: Bool

    private init(rawValue: String, value: String? = nil) {
        self.rawValue = rawValue
        self.value = value
        isEvent = false
    }

    init(event name: String, value: String?) {
        rawValue = name
        self.value = value
        isEvent = true
    }

    static func clock(_ seconds: TimeInterval?) -> ReadReason {
        seconds.map { ReadReason(rawValue: SpotEvent.clockPrefix + String(Int($0))) } ?? want
    }

    static func text(_ text: String, inSheet: Bool) -> ReadReason {
        ReadReason(rawValue: inSheet ? SpotEvent.sheetText : SpotEvent.searchText, value: text)
    }

    var isFrequent: Bool {
        isEvent || self == .want || [SpotEvent.searchText, SpotEvent.sheetText].contains(rawValue) || rawValue.hasPrefix(SpotEvent.clockPrefix)
    }

    var variables: [String: String] {
        ["OPENSPOT_REASON": rawValue].merging(value.map { ["OPENSPOT_VALUE": $0] } ?? [:]) { _, new in new }
    }
}
