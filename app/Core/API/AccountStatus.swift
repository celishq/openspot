import Foundation

struct AccountStatus: Encodable {
    let signedIn: Bool
    let npub: String?
    let backedUp: Bool?
    let sync: Bool?

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
