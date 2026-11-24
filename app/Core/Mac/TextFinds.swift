import Foundation

public struct TextFinds: Sendable {
    private typealias Extraction = @convention(c) (
        AnyObject, CFDate, CFTimeZone, UnsafeMutablePointer<DarwinBoolean>?, UnsafeMutablePointer<Unmanaged<AnyObject>?>?, UnsafeMutablePointer<Unmanaged<AnyObject>?>?
    ) -> DarwinBoolean

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue | NSTextCheckingResult.CheckingType.link.rawValue)
    private static let extraction = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "DDResultCopyExtractedDateFromReferenceDate").map { unsafeBitCast($0, to: Extraction.self) }
    private static let noon = 12 * 3600

    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var links: [URL] {
        matches(of: .link).compactMap(\.url)
    }

    public func date(now: Date? = nil, zone: TimeZone = .current) -> FoundDate? {
        guard let found = matches(of: .date, first: true).first, let range = Range(found.range, in: text),
              let date = now.flatMap({ Self.date(of: found, now: $0, zone: zone) }) ?? found.date else { return nil }
        return FoundDate(date: date, hasTime: Self.hasTime(found, at: date, zone: zone), range: range, length: found.duration > 0 ? found.duration : nil)
    }

    private func matches(of type: NSTextCheckingResult.CheckingType, first: Bool = false) -> [NSTextCheckingResult] {
        var found: [NSTextCheckingResult] = []
        Self.detector?.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, stop in
            guard let match, match.resultType == type else { return }
            found.append(match)
            if first { stop.pointee = true }
        }
        return found
    }

    private static func date(of found: NSTextCheckingResult, now: Date, zone: TimeZone) -> Date? {
        let key = "underlyingResult"
        guard let extraction, found.responds(to: NSSelectorFromString(key)), let underlying = found.value(forKey: key) else { return nil }
        var allDay: DarwinBoolean = false
        var date: Unmanaged<AnyObject>?
        var foundZone: Unmanaged<AnyObject>?
        let isRead = extraction(underlying as AnyObject, now as CFDate, zone as CFTimeZone, &allDay, &date, &foundZone).boolValue
        foundZone?.release()
        let value = date?.takeRetainedValue() as? Date
        return isRead ? value : nil
    }

    private static func hasTime(_ found: NSTextCheckingResult, at date: Date, zone: TimeZone) -> Bool {
        let key = "timeIsSignificant"
        if found.responds(to: NSSelectorFromString(key)), let isSignificant = found.value(forKey: key) as? Bool { return isSignificant }
        var calendar = Calendar.current
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0) != noon
    }
}
