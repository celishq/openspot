import Foundation

public struct SpotTrust: Equatable, Sendable {
    let entries: [SpotLock.Entry]
    let store: URL?
    let ownKey: String?
    var trusted: Set<Trusted> = []

    public init(entries: [SpotLock.Entry] = [], store: URL? = nil, ownKey: String? = nil) {
        self.entries = entries
        self.store = store
        self.ownKey = ownKey
    }

    func granting(_ trusted: [Trusted]) -> SpotTrust {
        var trust = self
        trust.trusted = Set(trusted)
        return trust
    }

    static func grant(of entry: SpotLock.Entry) -> Trusted {
        entry.key.map(Trusted.author) ?? .source(entry.source)
    }

    public static func read(lock: SpotLock, account: AccountStore, store: Store?) -> SpotTrust {
        let entries = (try? lock.entries()) ?? []
        let ownKey = entries.contains { $0.key != nil } ? (try? account.key())?.publicKey : nil
        return SpotTrust(entries: entries, store: store?.url, ownKey: ownKey)
    }

    public func isRestricted(_ spot: Spot) -> Bool {
        grant(lifting: spot) != nil
    }

    func applied(to spot: Spot) -> Spot {
        grant(lifting: spot).map { spot.restricted(lifting: $0) } ?? spot
    }

    private func grant(lifting spot: Spot) -> Trusted? {
        guard !spot.isBuiltIn, let entry = entries.first(where: { $0.holds(spot.id) }) else { return nil }
        if let store, entry.source.hasPrefix(store.path + "/") { return nil }
        if let key = entry.key, key == ownKey { return nil }
        let grant = Self.grant(of: entry)
        return trusted.contains(grant) ? nil : grant
    }
}
