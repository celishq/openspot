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

    private var accesses: [(AccessList.Entry, String)] = []
    private var standings: [(SpotStanding, String)] = []
    private var rows: [(SettingRow, String)] = []

    public init() {}

    init(accesses: [AccessList.Entry], standings: [SpotStanding], rows: [SettingRow]) {
        self.accesses = accesses.map { ($0, Self.fold($0.id.title)) }
        self.standings = standings.map { ($0, Self.fold($0.title + " " + $0.detail)) }
        self.rows = rows.map { ($0, Self.fold([$0.title, $0.detail ?? "", $0.kind == .key ? "shortcut key" : ""].joined(separator: " "))) }
    }

    public func found(_ query: String) -> Found {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespaces))
        return Found(
            accesses: accesses.filter { $0.1.contains(folded) }.map(\.0),
            standings: standings.filter { $0.1.contains(folded) }.map(\.0),
            rows: rows.filter { $0.1.contains(folded) }.map(\.0)
        )
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
