import Foundation

extension SettingsBook {
    private var keyAccount: Account? {
        guard let model else { return nil }
        return Account(store: model.files.account, allows: { [weak model] reason in await model?.allows(reason) ?? false })
    }

    public func makeAccount(handle: String?) async {
        await act { try $0.make(handle: handle) }
    }

    public func signOut() async {
        await act { try await $0.signOut() }
    }

    public func sync(_ isOn: Bool) async {
        await act { try await $0.sync(isOn) }
    }

    public func keep(secret value: String, of row: SettingRow) async {
        guard let model else { return }
        if let failure = await model.keep(secret: value, key: row.key, of: row.spot) {
            say(failure)
        } else {
            await read()
        }
    }

    public func words() async -> (words: [String], failure: String?) {
        guard let keyAccount else { return ([], nil) }
        do {
            return (try await keyAccount.words(), nil)
        } catch {
            return ([], Self.reason(error))
        }
    }

    public func choices(at places: [Int]) -> [[String]] {
        (try? keyAccount?.choices(at: places)) ?? []
    }

    public func confirm(_ places: [Int], _ picked: [String]) async -> String? {
        await failure { try await $0.confirm(Array(zip(places, picked)).map { (place: $0.0, word: $0.1) }) }
    }

    public func signIn(_ phrase: String) async -> String? {
        await failure { try await $0.signIn(AccountPhrase(phrase)) }
    }

    public func line(of phrase: String) -> [String: String] {
        AccountPhrase(phrase).line(isSignedIn: account?.signedIn == true)
    }

    private func act(_ work: (Account) async throws -> Void) async {
        if let failure = await failure(work) { model?.toast(.failure(failure)) }
    }

    private func failure(_ work: (Account) async throws -> Void) async -> String? {
        guard let keyAccount else { return nil }
        do {
            try await work(keyAccount)
            await read()
            return nil
        } catch {
            return Self.reason(error)
        }
    }

    private static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
