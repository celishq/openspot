import Foundation

struct AppStatus: Encodable {
    let version: String
    let panelKey: String
    let fixKey: String
    let careful: Bool
    let login: Bool?
    let link: Bool?
    let update: String?
    let calls: Int?
    let firstLaunch: Bool?

    func text(frame: Bool) throws -> String {
        guard frame else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
        }
        let pairs: [(String, String?)] = [
            ("version", version), ("panelKey", panelKey), ("fixKey", fixKey), ("careful", String(careful)), ("login", login.map(String.init)), ("link", link.map(String.init)),
            ("update", update), ("calls", calls.map(String.init)), ("firstLaunch", firstLaunch.map(String.init))
        ]
        return TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text
    }
}
