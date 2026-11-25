import Foundation

struct AccessList {
    let statuses: [MacAccess: ReadAccess]
    let spots: [Spot]

    var blocks: [TextBlock] {
        MacAccess.allCases.map { access in
            let users = spots.filter { Self.reaches(access, from: $0.uses) }
            let isOptional = !users.isEmpty && users.allSatisfy { !UseAccess.needs(of: $0.uses).contains(access) }
            let fields: [(String, String?)] = [
                ("item", access.rawValue), ("title", access.title), ("access", (statuses[access] ?? .unknown).rawValue),
                ("spots", users.isEmpty ? nil : users.map(\.id).joined(separator: ",")), ("optional", isOptional ? "true" : nil)
            ]
            return TextBlock(fields: fields.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } })
        }
    }

    static func needs(of spot: Spot, in statuses: [MacAccess: ReadAccess]) -> [MacAccess] {
        MacAccess.allCases.filter { UseAccess.needs(of: spot.uses).contains($0) && statuses[$0] != .allowed }
    }

    private static func reaches(_ access: MacAccess, from uses: Set<SpotUse>) -> Bool {
        uses.contains { use in UseAccess.all[use].map { $0.needs.contains(access) || $0.optional.contains(access) } ?? false }
    }
}
