import Foundation

/// One time of an event in a calendar. A repeating event gives one for each time.
public struct AgendaEvent: Equatable, Sendable {
    private static let meetingHosts = [
        "zoom.us", "zoom.com", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "whereby.com", "meet.jit.si",
        "facetime.apple.com", "gotomeeting.com", "chime.aws"
    ]

    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendar: AgendaList
    public let location: String?
    public let url: String?
    public let notes: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool, calendar: AgendaList, location: String?, url: String?, notes: String?) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.location = location
        self.url = url
        self.notes = notes
    }

    /// The address of a call in its address, location or notes, such as a Zoom or Meet link.
    var meeting: String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for text in [url, location, notes].compactMap(\.self) {
            let links = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url) ?? []
            if let link = links.first(where: Self.isMeeting) { return link.absoluteString }
        }
        return nil
    }

    /// Its row (E2). The id names this time of the event, so each time of a repeating event has its own.
    func row(_ clock: AgendaClock) -> TextBlock {
        let meeting = meeting
        let isOn = !isAllDay && start <= clock.now && clock.now < end
        var fields: [TextBlock.Field] = [
            .init(key: "row", value: "event:\(id)/\(Int(start.timeIntervalSince1970))"),
            .init(key: "title", value: title),
            .init(key: "detail", value: "\(when(clock)) · \(calendar.title)"),
            .init(key: "icon", value: meeting == nil ? "calendar" : "video"),
            .init(key: "tone", value: isOn ? "on" : ""),
            .init(key: "start", value: clock.iso(start)),
            .init(key: "end", value: clock.iso(end)),
            .init(key: "allday", value: isAllDay ? "true" : ""),
            .init(key: "calendar", value: calendar.id),
            .init(key: "color", value: calendar.color ?? ""),
            .init(key: "location", value: location ?? ""),
            .init(key: "meeting", value: meeting ?? "")
        ]
        fields.removeAll { $0.value.isEmpty }
        return TextBlock(fields: fields)
    }

    /// When it is, in words: its day unless it is today, then its times, or `All day`.
    private func when(_ clock: AgendaClock) -> String {
        let started = start < clock.startOfToday
        if isAllDay { return started ? "All day" : clock.day(start) ?? "All day" }
        if started { return "Until " + ([clock.day(end), clock.time(end)].compactMap(\.self).joined(separator: " ")) }
        return [clock.day(start), "\(clock.time(start))–\(clock.time(end))"].compactMap(\.self).joined(separator: " ")
    }

    private static func isMeeting(_ link: URL) -> Bool {
        guard let host = link.host?.lowercased(), link.scheme?.hasPrefix("http") == true else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
