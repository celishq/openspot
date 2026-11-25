import Foundation

public struct AccessList: Equatable, Sendable {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let id: MacAccess
        public let status: AccessStatus
        public let spots: [String]
        public let maybe: [String]

        public var isAllowed: Bool {
            status == .allowed
        }
    }

    public let entries: [Entry]

    init(statuses: [MacAccess: AccessStatus], standings: [SpotStanding]) {
        entries = MacAccess.allCases.map { access in
            Entry(
                id: access, status: statuses[access] ?? .unknown,
                spots: standings.filter { $0.needs.contains(access) }.map(\.id),
                maybe: standings.filter { $0.maybe.contains(access) }.map(\.id)
            )
        }
    }

    var blocks: [TextBlock] {
        entries.map { entry in
            let listed = { (ids: [String]) in ids.isEmpty ? nil : ids.joined(separator: ",") }
            let fields: [(String, String?)] = [
                ("item", entry.id.rawValue), ("title", entry.id.title), ("access", entry.status.rawValue), ("spots", listed(entry.spots)), ("maybe", listed(entry.maybe))
            ]
            return TextBlock(fields: fields.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } })
        }
    }
}
