import Foundation

struct Account: Sendable {
    static let refusal = "Only Openspot's Store can reach your account key."
    static let checkedPlaces = 2
    private static let noWords = "This Mac holds no account words."

    let store: AccountStore
    let allows: @Sendable (String) async -> Bool

    func admit(_ caller: CallerTokens.Caller?) throws {
        guard caller?.reachesAccountKey == true else { throw SpotError.failed(1, Self.refusal) }
    }

    func status() throws -> AccountStatus {
        let record = try store.record()
        return AccountStatus(
            signedIn: record != nil,
            npub: record?.key.npub,
            handle: record?.handle,
            since: record?.since,
            backedUp: record?.isBackedUp,
            sync: record == nil || !store.canSync() ? nil : try store.isSyncing()
        )
    }

    func make(handle: String?) throws {
        if let handle, AccountHandle(handle) == nil { throw SpotError.failed(1, AccountHandle.rule) }
        _ = try store.keyMadeOnce(handle: handle)
    }

    func words() async throws -> [String] {
        guard let words = try store.key()?.words else { throw SpotError.failed(1, Self.noWords) }
        try await unlock(to: "show your account words", or: "Openspot showed no words")
        return words
    }

    func signing() async throws -> AccountKey? {
        guard let key = try store.key() else { return nil }
        try await unlock(to: "sign your spot", or: "Openspot signed nothing")
        return key
    }

    func choices(at places: [Int]) throws -> [[String]] {
        guard let key = try store.key(), key.words != nil else { throw SpotError.failed(1, Self.noWords) }
        return places.map { key.choices(at: $0) }
    }

    func confirm(_ picks: [(place: Int, word: String)]) async throws {
        guard let words = try store.key()?.words else { throw SpotError.failed(1, Self.noWords) }
        try await unlock(to: "check your account words", or: "Openspot checked no words")
        let isRight = picks.allSatisfy { words.indices.contains($0.place - 1) && $0.word.lowercased() == words[$0.place - 1] }
        guard isRight, Set(picks.map(\.place)).count >= Self.checkedPlaces else {
            throw SpotError.failed(1, "One of these words is wrong. Look at your words again.")
        }
        try store.markBackedUp()
    }

    func signIn(_ phrase: AccountPhrase) async throws {
        guard phrase.canSignIn else { throw SpotError.failed(1, phrase.problem ?? "Type all 12 words first.") }
        let key = try phrase.key()
        try await unlock(to: "sign in to your account", or: "Openspot didn't sign in")
        try store.keep(key, isBackedUp: true)
    }

    func signOut() async throws {
        try await unlock(to: "sign out of your account", or: "your account stays")
        try store.remove()
    }

    func sync(_ isOn: Bool) async throws {
        try await unlock(to: "change where your account is kept", or: "your account stays where it is")
        try store.setSyncing(isOn)
    }

    private func unlock(to act: String, or outcome: String) async throws {
        guard await allows(act) else { throw SpotError.failed(1, "Touch ID didn't pass, so \(outcome).") }
    }
}
