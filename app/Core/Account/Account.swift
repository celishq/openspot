import Foundation

struct Account: Sendable {
    let store: AccountStore
    let allows: @Sendable (String) async -> Bool

    func status() throws -> AccountStatus {
        let key = try store.key()
        return AccountStatus(
            signedIn: key != nil,
            npub: key?.npub,
            name: key == nil ? nil : try store.name(),
            since: key == nil ? nil : try store.since(),
            backedUp: key == nil ? nil : try store.isBackedUp(),
            sync: key == nil || !store.canSync ? nil : try store.isSyncing()
        )
    }

    func make(name: String?) throws {
        _ = try store.keyMadeOnce(name: name)
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
