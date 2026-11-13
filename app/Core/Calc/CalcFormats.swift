import Foundation
import Synchronization

/// The formatters and the date finder of Calc, each made once for its locale, clock and way of writing, and only read after,
/// which is safe on any thread. It keeps at most `limit` of them, and drops them all when the person changes the language or
/// the region, whose number and date choices a locale's identifier does not name.
enum CalcFormats {
    nonisolated(unsafe) private static var formatters: [String: Formatter] = [:]
    private static let lock = Mutex(())
    /// The most formatters it keeps.
    static let limit = 32
    /// The watch of a change of the locale, which starts with the first formatter.
    nonisolated(unsafe) private static let localeWatch = NotificationCenter.default.addObserver(
        forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: nil
    ) { _ in
        lock.withLock { _ in formatters = [:] }
    }

    /// The number of formatters it keeps.
    static var count: Int {
        lock.withLock { _ in formatters.count }
    }

    /// The finder of a date in a whole text.
    static let dates = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    /// The formatter of this kind that `key` names, made by `make` the first time.
    static func formatter<Kind: Formatter>(_ kind: Kind.Type, _ key: String, make: () -> Kind) -> Kind {
        _ = localeWatch
        return lock.withLock { _ in
            if let kept = formatters[key] as? Kind { return kept }
            let made = make()
            if formatters.count >= limit { formatters = [:] }
            formatters[key] = made
            return made
        }
    }

    /// The part of a key that names a locale, a clock and a zone.
    static func key(_ locale: Locale, _ clock: Calendar? = nil, _ zone: TimeZone? = nil) -> String {
        [locale.identifier, clock.map { "\($0.identifier)" } ?? "", (zone ?? clock?.timeZone)?.identifier ?? ""].joined(separator: "|")
    }
}
