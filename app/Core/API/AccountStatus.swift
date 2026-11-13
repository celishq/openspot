import Foundation

/// What `openspot account status` prints as JSON, or as one block: whether an account is signed in, its `npub`, whether
/// its words were backed up, and whether it syncs through iCloud Keychain, absent when this copy of the app cannot sync.
struct AccountStatus: Encodable {
    let signedIn: Bool
    let npub: String?
    let backedUp: Bool?
    let sync: Bool?

    /// The state as JSON, or with `frame` as one block of `key=value` lines (protocol: The openspot command).
    func text(frame: Bool) throws -> String {
        guard frame else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
        }
        let pairs: [(String, String?)] = [("signedIn", String(signedIn)), ("npub", npub), ("backedUp", backedUp.map(String.init)), ("sync", sync.map(String.init))]
        return TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text
    }
}
