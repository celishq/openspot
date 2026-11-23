import Foundation

/// What `openspot date read` prints for the clock of the tests, read by NSDataDetector as the command reads it.
enum DateRead {
    private typealias Extraction = @convention(c) (
        AnyObject, CFDate, CFTimeZone, UnsafeMutablePointer<DarwinBoolean>?, UnsafeMutablePointer<Unmanaged<AnyObject>?>?, UnsafeMutablePointer<Unmanaged<AnyObject>?>?
    ) -> DarwinBoolean

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    /// The block of the date that the whole text names, item and time, or nothing.
    static func block(of words: String, now: Date, zone: TimeZone) -> String {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let found = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              found.range == NSRange(text.startIndex..., in: text),
              let date = date(of: found, now: now, zone: zone) else { return "" }
        let hasTime = found.value(forKey: "timeIsSignificant") as? Bool ?? false
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        let item = hasTime ? day + String(format: " %02d:%02d", parts.hour!, parts.minute!) : day
        return "item=\(item)\ntime=\(hasTime)\n"
    }

    /// The date of a match from the clock given, not from the clock of the Mac.
    private static func date(of found: NSTextCheckingResult, now: Date, zone: TimeZone) -> Date? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "DDResultCopyExtractedDateFromReferenceDate"),
              let underlying = found.value(forKey: "underlyingResult") else { return nil }
        let extraction = unsafeBitCast(symbol, to: Extraction.self)
        var allDay: DarwinBoolean = false
        var date: Unmanaged<AnyObject>?
        var foundZone: Unmanaged<AnyObject>?
        let isRead = extraction(underlying as AnyObject, now as CFDate, zone as CFTimeZone, &allDay, &date, &foundZone).boolValue
        foundZone?.release()
        let value = date?.takeRetainedValue() as? Date
        return isRead ? value : nil
    }
}
