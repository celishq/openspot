import Foundation

/// The codes of the languages of the Mac to try for a localized name, in order.
struct LanguageCodes {
    private static let fallback = "en"

    let languages: [String]

    /// Each language with its region, then with no region, then the last resort.
    var all: [String] {
        let exact = languages.flatMap { language -> [String] in
            let words = language.split(separator: "-").map(String.init)
            guard let first = words.first else { return [] }
            return [words.joined(separator: "_"), words.dropLast().joined(separator: "_"), first].filter { !$0.isEmpty }
        }
        return exact + [Self.fallback]
    }
}
