import Foundation

/// A use that a spot names in the `uses` of its header, such as `screen` (protocol: Trust).
public enum SpotUse: String, CaseIterable, Codable, Sendable {
    case app, spots, screen, clipboard, calendar, network, files

    /// The words that Openspot no longer reads, with the use that took each one.
    private static let merged: [String: SpotUse] = ["update": .app, "settings": .spots]

    /// Decodes a use, and an old word as the use that took it, so that a `spots.lock` of an older Openspot still reads.
    public init(from decoder: Decoder) throws {
        let word = try decoder.singleValueContainer().decode(String.self)
        guard let use = SpotUse(rawValue: word) ?? Self.merged[word] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown use: \(word)"))
        }
        self = use
    }

    /// The uses that a `uses` value names. An unknown word is a fault that names the key.
    static func set(_ text: String?, of name: String) throws -> Set<SpotUse> {
        var uses: Set<SpotUse> = []
        for word in SpotRead.words(text) {
            if let use = merged[word] {
                throw SpotError.fault("\(name) has \(word) in its uses, which Openspot no longer reads. Write \(use.rawValue)")
            }
            guard let use = SpotUse(rawValue: word) else {
                let known = allCases.map(\.rawValue)
                throw SpotError.fault("\(name) has an unknown use in its uses: \(word). Use \(known.dropLast().joined(separator: ", ")) or \(known.last ?? "")")
            }
            uses.insert(use)
        }
        return uses
    }
}
