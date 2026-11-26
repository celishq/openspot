import Foundation

public struct SettingsIndex: Sendable {
    public struct Found: Equatable, Sendable {
        public let accesses: [AccessList.Entry]
        public let standings: [SpotStanding]
        public let rows: [SettingRow]

        static let none = Found(accesses: [], standings: [], rows: [])

        public var isEmpty: Bool {
            accesses.isEmpty && standings.isEmpty && rows.isEmpty
        }
    }

    private var accesses = SearchList<AccessList.Entry>()
    private var standings = SearchList<SpotStanding>()
    private var rows = SearchList<SettingRow>()

    public init() {}

    init(accesses: [AccessList.Entry], standings: [SpotStanding], rows: [SettingRow]) {
        self.accesses = SearchList(accesses) { SearchText(title: $0.id.title) }
        self.standings = SearchList(standings) { SearchText(title: $0.title, subtitle: $0.detail) }
        self.rows = SearchList(rows) { SearchText(title: $0.title, subtitle: $0.detail, keywords: $0.kind == .key ? ["shortcut", "key"] : []) }
    }

    public func found(_ query: String) -> Found {
        let query = SearchQuery(text: query)
        return Found(accesses: accesses.matching(query), standings: standings.matching(query), rows: rows.matching(query))
    }
}
