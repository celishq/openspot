import Foundation
import Synchronization

enum CalcFormats {
    nonisolated(unsafe) private static var formatters: [String: Formatter] = [:]
    private static let lock = Mutex(())
    static let limit = 32
    nonisolated(unsafe) private static let localeWatch = NotificationCenter.default.addObserver(
        forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: nil
    ) { _ in
        lock.withLock { _ in formatters = [:] }
    }

    static var count: Int {
        lock.withLock { _ in formatters.count }
    }

    static let dateFinder = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

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

    static func key(_ locale: Locale, _ clock: Calendar? = nil, _ zone: TimeZone? = nil) -> String {
        [locale.identifier, clock.map { "\($0.identifier)" } ?? "", (zone ?? clock?.timeZone)?.identifier ?? ""].joined(separator: "|")
    }
}
