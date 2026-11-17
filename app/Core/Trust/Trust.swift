import Foundation

public struct Trust: Equatable, Sendable {
    let entries: [SpotLock.Entry]
    let store: URL?
    let ownKey: String?
    var grants: Set<TrustGrant> = []
    public private(set) var isCareful: Bool

    public init(entries: [SpotLock.Entry] = [], store: URL? = nil, ownKey: String? = nil, isCareful: Bool = false) {
        self.entries = entries
        self.store = store
        self.ownKey = ownKey
        self.isCareful = isCareful
    }

    func applying(_ config: Config) -> Trust {
        var trust = self
        trust.grants = Set(config.grants)
        trust.isCareful = config.isCareful
        return trust
    }

    static func grant(of entry: SpotLock.Entry) -> TrustGrant {
        entry.key.map(TrustGrant.author) ?? .source(entry.source)
    }

    public static func read(lock: SpotLock, account: AccountStore, store: Store?) -> Trust {
        let entries = (try? lock.entries()) ?? []
        let ownKey = entries.contains { $0.key != nil } ? account.publicKey() : nil
        return Trust(entries: entries, store: store?.url, ownKey: ownKey)
    }

    func applied(to spot: Spot) -> Spot {
        if let grant = grant(lifting: spot) { return spot.restricted(.untrusted(grant)) }
        return isCareful && !spot.isBuiltIn ? spot.restricted(.careful) : spot
    }

    private func grant(lifting spot: Spot) -> TrustGrant? {
        guard !spot.isBuiltIn, let entry = entries.first(where: { $0.holds(spot.id) }) else { return nil }
        if entry.isShipped ?? store.map({ entry.source.hasPrefix($0.path + "/") }) == true { return nil }
        if let key = entry.key, key == ownKey { return nil }
        let grant = Self.grant(of: entry)
        return grants.contains(grant) ? nil : grant
    }
}
