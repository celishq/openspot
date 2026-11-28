import Foundation

public struct SpotEvent: Equatable, Sendable {
    public let name: String
    public let takesValue: Bool
    public let words: String?

    public static let all = [
        SpotEvent(name: EventName.panelOpen, takesValue: true, words: "when the panel opens"),
        SpotEvent(name: EventName.sheetOpen, takesValue: false, words: nil),
        SpotEvent(name: EventName.spotWant, takesValue: false, words: "when it first shows"),
        SpotEvent(name: EventName.sheetText, takesValue: false, words: nil),
        SpotEvent(name: EventName.sheetMore, takesValue: false, words: nil),
        SpotEvent(name: EventName.clipboard, takesValue: false, words: "when you copy"),
        SpotEvent(name: EventName.frontApp, takesValue: true, words: "when you switch apps"),
        SpotEvent(name: EventName.appUpdate, takesValue: true, words: "when Openspot downloads an update"),
        SpotEvent(name: EventName.appLaunch, takesValue: false, words: "when Openspot starts"),
        SpotEvent(name: EventName.screenWake, takesValue: false, words: "when the screen wakes"),
        SpotEvent(name: EventName.systemLoad, takesValue: true, words: "every 5 seconds while it shows"),
        SpotEvent(name: EventName.powerChange, takesValue: true, words: "when the power changes"),
        SpotEvent(name: EventName.diskMount, takesValue: true, words: "when a disk mounts"),
        SpotEvent(name: EventName.deviceConnect, takesValue: true, words: "when a USB device connects"),
        SpotEvent(name: EventName.calendarChange, takesValue: false, words: "when an event of your calendars changes"),
        SpotEvent(name: EventName.remindersChange, takesValue: false, words: "when a reminder changes")
    ]

    public static func named(_ name: String) -> SpotEvent? {
        all.first { $0.name == name }
    }
}
