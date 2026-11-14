import Foundation

public enum SpotUse: String, CaseIterable, Codable, Sendable {
    case app, spots, screen, clipboard, calendar, network, files
    case account

    static func reachesAccountKey(_ uses: Set<SpotUse>, isBuiltIn: Bool) -> Bool {
        isBuiltIn && uses.contains(.account)
    }

    private static let merged: [String: SpotUse] = ["update": .app, "settings": .spots]

    public init(from decoder: Decoder) throws {
        let word = try decoder.singleValueContainer().decode(String.self)
        guard let use = SpotUse(rawValue: word) ?? Self.merged[word] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown use: \(word)"))
        }
        self = use
    }

    static func set(_ text: String?, of name: String) throws -> Set<SpotUse> {
        var uses: Set<SpotUse> = []
        for word in SpotRead.words(text) {
            if let use = merged[word] {
                throw SpotError.fault("\(name) has \(word) in its uses, which Openspot no longer reads. Write \(use.rawValue)")
            }
            guard let use = SpotUse(rawValue: word) else {
                let known = allCases.filter { $0 != .account }.map(\.rawValue)
                throw SpotError.fault("\(name) has an unknown use in its uses: \(word). Use \(known.dropLast().joined(separator: ", ")) or \(known.last ?? "")")
            }
            uses.insert(use)
        }
        return uses
    }
}
