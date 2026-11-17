import Foundation

public struct SpotTrust: Equatable, Sendable {
    let entries: [SpotLock.Entry]
    let store: URL?
    let ownKey: String?
    var trusted: Set<Trusted> = []
    public private(set) var isCareful: Bool

    public init(entries: [SpotLock.Entry] = [], store: URL? = nil, ownKey: String? = nil, isCareful: Bool = false) {
        self.entries = entries
        self.store = store
        self.ownKey = ownKey
        self.isCareful = isCareful
    }

    func applying(_ config: Config) -> SpotTrust {
        var trust = self
        trust.trusted = Set(config.trusted)
        trust.isCareful = config.isCareful
        return trust
    }

    static func grant(of entry: SpotLock.Entry) -> Trusted {
        entry.key.map(Trusted.author) ?? .source(entry.source)
    }

    public static func read(lock: SpotLock, account: AccountStore, store: Store?, ownKey known: String?? = nil) -> SpotTrust {
        let entries = (try? lock.entries()) ?? []
        let ownKey = entries.contains { $0.key != nil } ? known ?? (try? account.key())?.publicKey : nil
        return SpotTrust(entries: entries, store: store?.url, ownKey: ownKey)
    }

    var needsOwnKey: Bool {
        entries.contains { $0.key != nil }
    }

    func applied(to spot: Spot) -> Spot {
        if let grant = grant(lifting: spot) { return spot.restricted(lifting: grant) }
        return isCareful && !spot.isBuiltIn ? spot.restricted() : spot
    }

    private func grant(lifting spot: Spot) -> Trusted? {
        guard !spot.isBuiltIn, let entry = entries.first(where: { $0.holds(spot.id) }) else { return nil }
        if let store, entry.source.hasPrefix(store.path + "/") { return nil }
        if let key = entry.key, key == ownKey { return nil }
        let grant = Self.grant(of: entry)
        return trusted.contains(grant) ? nil : grant
    }
}
