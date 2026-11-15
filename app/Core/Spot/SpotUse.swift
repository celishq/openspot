import Foundation

public enum SpotUse: String, CaseIterable, Codable, Sendable {
    case app, spots, screen, clipboard, calendar, network, files
    case account

    static func reachesAccountKey(_ uses: Set<SpotUse>, isBuiltIn: Bool) -> Bool {
        isBuiltIn && uses.contains(.account)
    }

    static func set(_ text: String?, of name: String) throws -> Set<SpotUse> {
        var uses: Set<SpotUse> = []
        for word in SpotRead.words(text) {
            guard let use = SpotUse(rawValue: word) else {
                let known = allCases.filter { $0 != .account }.map(\.rawValue)
                throw SpotError.fault("\(name) has an unknown use in its uses: \(word). Use \(known.dropLast().joined(separator: ", ")) or \(known.last ?? "")")
            }
            uses.insert(use)
        }
        return uses
    }
}
