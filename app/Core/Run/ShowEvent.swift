import Foundation

public struct ShowEvent: Equatable, Sendable {
    public static let panel = ShowEvent(rawValue: SpotEvent.panelOpen)
    public static let sheet = ShowEvent(rawValue: SpotEvent.sheetOpen)
    public static let want = ShowEvent(rawValue: "spot.want")
    public static let change = ShowEvent(rawValue: "spot.change")

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

    static func clock(_ seconds: TimeInterval?) -> ShowEvent {
        seconds.map { ShowEvent(rawValue: SpotEvent.clockPrefix + String(Int($0))) } ?? want
    }

    static func text(_ text: String, inSheet: Bool) -> ShowEvent {
        ShowEvent(rawValue: inSheet ? SpotEvent.sheetText : SpotEvent.searchText, value: text)
    }

    var isFrequent: Bool {
        isEvent || self == .want || [SpotEvent.searchText, SpotEvent.sheetText].contains(rawValue) || rawValue.hasPrefix(SpotEvent.clockPrefix)
    }
}
