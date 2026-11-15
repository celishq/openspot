import Foundation

struct Account: Sendable {
    let store: AccountStore
    let allows: @Sendable (String) async -> Bool

    func status() throws -> AccountStatus {
        let record = try store.record()
        return AccountStatus(
            signedIn: record != nil,
            npub: record?.key.npub,
            handle: record?.handle,
            since: record?.since,
            backedUp: record?.isBackedUp,
            sync: record == nil || !store.canSync ? nil : try store.isSyncing()
        )
    }

    func make(handle: String?) throws {
        if let handle, AccountHandle(handle) == nil { throw SpotError.failed(1, AccountHandle.rule) }
        _ = try store.keyMadeOnce(handle: handle)
    }

    func words() async throws -> [String] {
        guard let words = try store.key()?.words else { throw SpotError.failed(1, "This Mac holds no account words.") }
        guard await allows("show your account words") else { throw SpotError.failed(1, "Touch ID didn't pass, so Openspot showed no words.") }
        return words
    }

    func choices(at places: [Int]) throws -> [[String]] {
        guard let key = try store.key(), key.words != nil else { throw SpotError.failed(1, "This Mac holds no account words.") }
        return places.map { key.choices(at: $0) }
    }

    func confirm(_ picks: [(place: Int, word: String)]) throws {
        guard let words = try store.key()?.words else { throw SpotError.failed(1, "This Mac holds no account words.") }
        for pick in picks where words.indices.contains(pick.place - 1) && pick.word.lowercased() != words[pick.place - 1] {
            throw SpotError.failed(1, "That isn't word \(pick.place). Look at your words again.")
        }
        try store.markBackedUp()
    }

    func signIn(_ phrase: AccountPhrase) throws {
        guard phrase.canSignIn else { throw SpotError.failed(1, phrase.problem ?? "Type all 12 words first.") }
        try store.keep(try phrase.key(), isBackedUp: true)
    }

    func signOut() async throws {
        guard await allows("sign out of your account") else { throw SpotError.failed(1, "Touch ID didn't pass, so your account stays.") }
        try store.remove()
    }

    func sync(_ isOn: Bool) throws {
        try store.setSyncing(isOn)
    }
}
