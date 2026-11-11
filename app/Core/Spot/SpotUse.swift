import Foundation

/// A power that a spot names in the `uses` of its header (Z3).
public enum SpotUse: String, CaseIterable, Codable, Sendable {
    case app, update, spots, settings, screen, clipboard, calendar, network, files

    /// The uses that a `uses` value names. An unknown word is a fault that names the key.
    static func set(_ text: String?, of name: String) throws -> Set<SpotUse> {
        var uses: Set<SpotUse> = []
        for word in SpotRead.words(text) {
            guard let use = SpotUse(rawValue: word) else {
                let known = allCases.map(\.rawValue)
                throw SpotError.fault("\(name) has an unknown use in its uses: \(word). Use \(known.dropLast().joined(separator: ", ")) or \(known.last ?? "")")
            }
            uses.insert(use)
        }
        return uses
    }
}
