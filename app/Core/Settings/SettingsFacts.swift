import Foundation

public struct SettingsFacts: Sendable {
    public struct Look: Identifiable, Equatable, Sendable {
        public let id: String
        public let isUsed: Bool
        public let isBuiltIn: Bool
        public let colours: Theme.Colours
        public let layout: Theme.Layout

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

    let access: AccessFacts
    let spots: SpotStandings
    let keys: KeyMap
    let rows: SettingRows
    let looks: [Look]
    let account: Account?

    init(accesses: [AccessList.Entry], loaded: [SpotStanding], core: [SpotList.Choice], rows: [SettingRow], looks: [ThemeCall.Listed], account: AccountStatus?) {
        access = AccessFacts(accesses)
        spots = SpotStandings(loaded: loaded, core: core)
        keys = KeyMap(rows)
        self.rows = SettingRows(rows)
        self.looks = looks.map { Look(id: $0.name, isUsed: $0.isUsed, isBuiltIn: $0.isBuiltIn, colours: $0.colours, layout: $0.layout) }
        self.account = account.map { status in
            Account(isSignedIn: status.signedIn, handle: status.handle, npub: status.npub, since: status.since, isBackedUp: status.backedUp == true, sync: status.sync)
        }
    }
}
