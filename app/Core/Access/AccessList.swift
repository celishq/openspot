import Foundation

struct AccessList {
    let statuses: [MacAccess: ReadAccess]
    let spots: [(id: String, access: SpotAccess)]

    var blocks: [TextBlock] {
        MacAccess.allCases.map { access in
            let fields: [(String, String?)] = [
                ("item", access.rawValue), ("title", access.title), ("access", (statuses[access] ?? .unknown).rawValue),
                ("spots", listed { $0.needs.contains(access) }), ("maybe", listed { $0.maybe.contains(access) })
            ]
            return TextBlock(fields: fields.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } })
        }
    }

    private func listed(_ isIn: (SpotAccess) -> Bool) -> String? {
        let ids = spots.filter { isIn($0.access) }.map(\.id)
        return ids.isEmpty ? nil : ids.joined(separator: ",")
    }
}
