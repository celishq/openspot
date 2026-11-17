import Foundation

public struct SpotTrust: Equatable, Sendable {
    let entries: [SpotLock.Entry]
    let store: URL?
    let ownKey: String?

    public init(entries: [SpotLock.Entry] = [], store: URL? = nil, ownKey: String? = nil) {
        self.entries = entries
        self.store = store
        self.ownKey = ownKey
    }

    public static func read(lock: SpotLock, account: AccountStore, store: Store?) -> SpotTrust {
        let entries = (try? lock.entries()) ?? []
        let ownKey = entries.contains { $0.key != nil } ? (try? account.key())?.publicKey : nil
        return SpotTrust(entries: entries, store: store?.url, ownKey: ownKey)
    }

    public func isRestricted(_ spot: Spot) -> Bool {
        guard !spot.isBuiltIn, let entry = entries.first(where: { $0.holds(spot.id) }) else { return false }
        if let store, entry.source.hasPrefix(store.path + "/") { return false }
        if let key = entry.key, key == ownKey { return false }
        return true
    }

    func applied(to spot: Spot) -> Spot {
        isRestricted(spot) ? spot.restricted() : spot
    }
}
