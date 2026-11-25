import Foundation

public struct SettingsFacts: Equatable, Sendable {
    public struct Access: Identifiable, Equatable, Sendable {
        public let id: MacAccess
        public let status: ReadAccess
        public let spots: [String]
        public let maybe: [String]

        public var isAllowed: Bool {
            status == .allowed
        }
    }

    public struct Standing: Identifiable, Equatable, Sendable {
        public struct Use: Identifiable, Equatable, Sendable {
            public let id: SpotUse
            public let needs: [MacAccess]
            public let maybe: [MacAccess]
        }

        public let id: String
        public let spot: Spot
        public let readiness: SpotReadiness
        public let uses: [Use]
        public let needs: [MacAccess]
        public let refused: [SpotUse]
        let words: String

        public var title: String {
            spot.name
        }

        public var detail: String {
            spot.subtitle ?? ""
        }

        public var lacks: Bool {
            readiness == .access || readiness == .review
        }

        public var isOff: Bool {
            readiness == .off
        }
    }

    public struct Look: Identifiable, Equatable, Sendable {
        public let id: String
        public let isUsed: Bool
        public let isBuiltIn: Bool
        public let colours: Theme.Colours
    }

    public struct Account: Equatable, Sendable {
        public let isSignedIn: Bool
        public let handle: String?
        public let npub: String?
        public let since: String?
        public let isBackedUp: Bool
        public let sync: Bool?
    }

    public struct Found: Equatable, Sendable {
        public let accesses: [Access]
        public let standings: [Standing]
        public let rows: [SettingRow]

        public var isEmpty: Bool {
            accesses.isEmpty && standings.isEmpty && rows.isEmpty
        }
    }

    public private(set) var accesses: [Access] = []
    public private(set) var standings: [Standing] = []
    public private(set) var rows: [SettingRow] = []
    public private(set) var looks: [Look] = []
    public private(set) var account: Account?
    public private(set) var clashes: [[SettingRow]] = []
    public private(set) var clashing: Set<String> = []
    private var rowWords: [String] = []
    private var accessWords: [String] = []

    public init() {}

    init(accesses list: AccessList?, loaded: [SpotList.Record], core: [SpotList.Record], rows: [SettingRow], looks: [ThemeCall.Listed], account: AccountStatus?) {
        if let list {
            accesses = MacAccess.allCases.map { access in
                Access(
                    id: access, status: list.statuses[access] ?? .unknown,
                    spots: list.spots.filter { $0.access.needs.contains(access) }.map(\.id),
                    maybe: list.spots.filter { $0.access.maybe.contains(access) }.map(\.id)
                )
            }
        }
        var seen = Set<String>()
        standings = (loaded + core.filter { !$0.isOn })
            .filter { !$0.id.hasPrefix(ReservedSetting.appSpot + "/") && seen.insert($0.id).inserted }
            .map { record in
                let access = record.access
                return Standing(
                    id: record.id, spot: record.spot, readiness: access.readiness,
                    uses: access.uses.map { use in Standing.Use(id: use, needs: access.byUse[use]?.needs ?? [], maybe: access.byUse[use]?.maybe ?? []) },
                    needs: access.needs, refused: access.refused, words: Self.fold(record.spot.name + " " + (record.spot.subtitle ?? ""))
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        self.rows = rows
        rowWords = rows.map { Self.fold($0.title + " " + ($0.detail ?? "")) }
        accessWords = accesses.map { Self.fold($0.id.title) }
        self.looks = looks.map { Look(id: $0.name, isUsed: $0.isUsed, isBuiltIn: $0.isBuiltIn, colours: $0.colours) }
        self.account = account.map { status in
            Account(isSignedIn: status.signedIn, handle: status.handle, npub: status.npub, since: status.since, isBackedUp: status.backedUp == true, sync: status.sync)
        }
        let keyed = rows.filter { $0.kind == .key && !($0.value ?? "").isEmpty && $0.value != "none" }
        clashes = Dictionary(grouping: keyed) { Self.normal($0.value ?? "") }.values.filter { $0.count > 1 }.sorted { ($0[0].value ?? "") < ($1[0].value ?? "") }
        clashing = Set(clashes.flatMap { $0.map(\.item) })
    }

    public var waiting: [Standing] {
        standings.filter(\.lacks)
    }

    public func standing(_ id: String) -> Standing? {
        standings.first { $0.id == id }
    }

    public func access(_ id: MacAccess) -> Access? {
        accesses.first { $0.id == id }
    }

    public func row(_ item: String) -> SettingRow? {
        rows.first { $0.item == item }
    }

    public func title(ofSpot id: String) -> String {
        standing(id)?.title ?? rows.first { $0.spot == id }?.name ?? id
    }

    public func rows(of spot: String) -> [SettingRow] {
        rows.filter { $0.spot == spot }
    }

    public func found(_ query: String) -> Found {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespaces))
        return Found(
            accesses: zip(accesses, accessWords).filter { $0.1.contains(folded) }.map(\.0),
            standings: standings.filter { $0.words.contains(folded) },
            rows: zip(rows, rowWords).filter { $0.1.contains(folded) }.map(\.0)
        )
    }

    public func names(_ accesses: [MacAccess]) -> String {
        let titles = accesses.map(\.title)
        guard titles.count > 1 else { return titles.first ?? "" }
        return titles.dropLast().joined(separator: ", ") + " and " + titles[titles.count - 1]
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func normal(_ key: String) -> String {
        let words = key.lowercased().split(separator: "+").map(String.init)
        return (words.dropLast().sorted() + words.suffix(1)).joined(separator: "+")
    }
}
