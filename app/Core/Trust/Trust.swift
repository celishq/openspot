import Foundation

public struct Trust: Equatable, Sendable {
    let entries: [SpotLock.Entry]
    let ownKey: String?
    var grants: Set<TrustGrant> = []

    public init(entries: [SpotLock.Entry] = [], ownKey: String? = nil) {
        self.entries = entries
        self.ownKey = ownKey
    }

    func applying(_ config: Config) -> Trust {
        var trust = self
        trust.grants = Set(config.grants)
        return trust
    }

    static func grant(of entry: SpotLock.Entry) -> TrustGrant {
        entry.key.map(TrustGrant.author) ?? .source(entry.source)
    }

    public static func read(lock: SpotLock, account: AccountStore) -> Trust {
        let entries = (try? lock.entries()) ?? []
        let ownKey = entries.contains { $0.key != nil } ? account.publicKey() : nil
        return Trust(entries: entries, ownKey: ownKey)
    }

    func applied(to spot: Spot) -> Spot {
        grant(lifting: spot).map { spot.restricted(.untrusted($0)) } ?? spot
    }

    private func grant(lifting spot: Spot) -> TrustGrant? {
        guard !spot.isBuiltIn, let entry = entries.first(where: { $0.holds(spot.id) }) else { return nil }
        if entry.isShipped == true { return nil }
        if let key = entry.key, key == ownKey { return nil }
        let grant = Self.grant(of: entry)
        return grants.contains(grant) ? nil : grant
    }
}
