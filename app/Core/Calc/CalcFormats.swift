import Foundation
import Synchronization

/// The formatters and the date finder of Calc, each made once for its locale, clock and way of writing, and only read after,
/// which is safe on any thread.
enum CalcFormats {
    nonisolated(unsafe) private static var formatters: [String: Formatter] = [:]
    private static let lock = Mutex(())

    /// The finder of a date in a whole text.
    static let dates = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    /// The formatter of this kind that `key` names, made by `make` the first time.
    static func formatter<Kind: Formatter>(_ kind: Kind.Type, _ key: String, make: () -> Kind) -> Kind {
        lock.withLock { _ in
            if let kept = formatters[key] as? Kind { return kept }
            let made = make()
            formatters[key] = made
            return made
        }
    }

    /// The part of a key that names a locale, a clock and a zone.
    static func key(_ locale: Locale, _ clock: Calendar? = nil, _ zone: TimeZone? = nil) -> String {
        [locale.identifier, clock.map { "\($0.identifier)" } ?? "", (zone ?? clock?.timeZone)?.identifier ?? ""].joined(separator: "|")
    }
}
