import Foundation

public struct SettingsFacts: Equatable, Sendable {
    public struct Look: Identifiable, Equatable, Sendable {
        public let id: String
        public let isUsed: Bool
        public let isBuiltIn: Bool
        public let colours: Theme.Colours

        public var word: String {
            isUsed ? "In use" : isBuiltIn ? "Built in" : "Yours"
        }
    }

    public struct Account: Equatable, Sendable {
        public let isSignedIn: Bool
        public let handle: String?
        public let npub: String?
        public let since: String?
        public let isBackedUp: Bool
        public let sync: Bool?

        public var lines: [Line] {
            [("handle", "Handle", handle), ("npub", "Public key", npub), ("since", "Since", since)].compactMap { id, title, value in value.map { Line(id: id, title: title, value: $0) } }
        }
    }

    public struct Line: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let value: String
    }

    public struct Clash: Equatable, Sendable {
        public let rows: [SettingRow]

        public var title: String {
            Shortcut.caps(rows.first?.value ?? "").joined() + " does \(rows.count == 2 ? "two" : "\(rows.count)") things"
        }

        public var line: String {
            rows.map { "\($0.name) · \($0.title)" }.joined(separator: " and ") + ". Change one of them."
        }
    }

    public struct RowGroup: Identifiable, Equatable, Sendable {
        public let id: String
        public let rows: [SettingRow]
    }

    public struct Found: Equatable, Sendable {
        public let accesses: [AccessList.Entry]
        public let standings: [SpotStanding]
        public let rows: [SettingRow]

        public var isEmpty: Bool {
            accesses.isEmpty && standings.isEmpty && rows.isEmpty
        }
    }

    public private(set) var accesses: [AccessList.Entry] = []
    public private(set) var needed: [AccessList.Entry] = []
    public private(set) var unneeded: [AccessList.Entry] = []
    public private(set) var keyRows: [SettingRow] = []
    public private(set) var standings: [SpotStanding] = []
    public private(set) var rows: [SettingRow] = []
    public private(set) var looks: [Look] = []
    public private(set) var account: Account?
    public private(set) var clashes: [Clash] = []
    public private(set) var clashing: Set<String> = []
    private var standingWords: [String] = []
    private var rowWords: [String] = []
    private var accessWords: [String] = []

    public init() {}

    init(accesses: [AccessList.Entry], loaded: [SpotStanding], core: [SpotList.Choice], rows: [SettingRow], looks: [ThemeCall.Listed], account: AccountStatus?) {
        self.accesses = accesses
        needed = accesses.filter { !$0.spots.isEmpty }
        unneeded = accesses.filter { $0.spots.isEmpty }
        var seen = Set<String>()
        standings = (loaded + core.map(\.standing).filter(\.isOff))
            .filter { !$0.id.hasPrefix(ReservedSetting.appSpot + "/") && seen.insert($0.id).inserted }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        standingWords = standings.map { Self.fold($0.title + " " + $0.detail) }
        self.rows = rows
        rowWords = rows.map { Self.fold($0.title + " " + ($0.detail ?? "")) }
        accessWords = accesses.map { Self.fold($0.id.title) }
        self.looks = looks.map { Look(id: $0.name, isUsed: $0.isUsed, isBuiltIn: $0.isBuiltIn, colours: $0.colours) }
        self.account = account.map { status in
            Account(isSignedIn: status.signedIn, handle: status.handle, npub: status.npub, since: status.since, isBackedUp: status.backedUp == true, sync: status.sync)
        }
        let keyed = rows.filter { $0.kind == .key && !($0.value ?? "").isEmpty && $0.value != "none" }
        let clashing = Dictionary(grouping: keyed) { Self.normal($0.value ?? "") }.values.filter { $0.count > 1 }.sorted { ($0[0].value ?? "") < ($1[0].value ?? "") }
        clashes = clashing.map(Clash.init)
        self.clashing = Set(clashing.flatMap { $0.map(\.item) })
        keyRows = rows.filter { $0.kind == .key }
    }

    public var waiting: [SpotStanding] {
        standings.filter(\.lacks)
    }

    public func standing(_ id: String) -> SpotStanding? {
        standings.first { $0.id == id }
    }

    public func access(_ id: MacAccess) -> AccessList.Entry? {
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

    public func rows(in section: SettingsPage.Section) -> [SettingRow] {
        rows.filter { $0.spot == ReservedSetting.appSpot && $0.section == section }
    }

    public func found(_ query: String) -> Found {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespaces))
        return Found(
            accesses: zip(accesses, accessWords).filter { $0.1.contains(folded) }.map(\.0),
            standings: zip(standings, standingWords).filter { $0.1.contains(folded) }.map(\.0),
            rows: zip(rows, rowWords).filter { $0.1.contains(folded) }.map(\.0)
        )
    }

    public func groups(of spot: String) -> [RowGroup] {
        let rows = rows(of: spot)
        let kinds: [(String, Set<SettingRow.Kind>)] = [("Keys", [.key]), ("Settings", [.field, .text, .secret, .choice]), ("Where it shows", [.toggle])]
        return kinds.map { title, kinds in RowGroup(id: title, rows: rows.filter { kinds.contains($0.kind) }) }.filter { !$0.rows.isEmpty }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func normal(_ key: String) -> String {
        let words = key.lowercased().split(separator: "+").map(String.init)
        return (words.dropLast().sorted() + words.suffix(1)).joined(separator: "+")
    }
}
