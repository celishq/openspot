import Foundation

struct LanguageCodes {
    private static let fallback = "en"

    let languages: [String]

    var all: [String] {
        let exact = languages.flatMap { language -> [String] in
            let words = language.split(separator: "-").map(String.init)
            guard let first = words.first else { return [] }
            return [words.joined(separator: "_"), words.dropLast().joined(separator: "_"), first].filter { !$0.isEmpty }
        }
        return exact + [Self.fallback]
    }
}
