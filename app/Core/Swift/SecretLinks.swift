import Foundation

public struct SecretLinks: Sendable {
    public static let key = "secrets"

    let account: Account
    let keep: @Sendable (String, String, String) async -> String?

    init(account: Account, keep: @escaping @Sendable (String, String, String) async -> String?) {
        self.account = account
        self.keep = keep
    }

    @MainActor
    public init(model: SpotsModel) {
        account = Account(store: model.files.account, allows: { [weak model] reason in await model?.allows(reason) ?? false })
        keep = { [weak model] value, key, spot in await model?.keep(secret: value, key: key, of: spot) ?? "Openspot is quitting." }
    }

    public static func isGiven(to source: String, core: URL?) -> Bool {
        guard let core else { return false }
        return source.hasPrefix(core.appendingPathComponent(SpotsFolder.appName, isDirectory: true).standardizedFileURL.path + "/")
    }

    public var input: [String: Any] {
        let account = account
        let keep: (String, String, String) async -> String? = self.keep
        let words: () async -> ([String], String?) = {
            do {
                return (try await account.words(), nil)
            } catch {
                return ([], Self.reason(error))
            }
        }
        let choices: ([Int]) -> [[String]] = { places in (try? account.choices(at: places)) ?? [] }
        let confirm: ([Int], [String]) async -> String? = { places, picked in
            await Self.failure { try await account.confirm(Array(zip(places, picked)).map { (place: $0.0, word: $0.1) }) }
        }
        let signIn: (String) async -> String? = { phrase in await Self.failure { try await account.signIn(AccountPhrase(phrase)) } }
        let line: (String) -> [String: String] = { phrase in AccountPhrase(phrase).line(isSignedIn: (try? account.status().signedIn) == true) }
        return ["keep": keep, "words": words, "choices": choices, "confirm": confirm, "signIn": signIn, "line": line]
    }

    private static func failure(_ work: () async throws -> Void) async -> String? {
        do {
            try await work()
            return nil
        } catch {
            return reason(error)
        }
    }

    private static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
