import Foundation

/// The languages to translate into: those the person prefers, each once, with no country and without the source.
public struct TranslationTargets: Equatable, Sendable {
    public let codes: [String]

    public init(preferred: [String], source: String) {
        var codes: [String] = []
        for identifier in preferred {
            let code = String(identifier.prefix { $0 != "-" && $0 != "_" })
            if code != source, !codes.contains(code) { codes.append(code) }
        }
        self.codes = codes
    }
}
