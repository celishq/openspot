import Foundation

/// What `openspot app status` prints as JSON, or as one block. A value that only the running app knows is absent in a
/// process of its own.
struct AppStatus: Encodable {
    let version: String
    let panelKey: String
    let fixKey: String
    /// Whether each spot runs with only what its uses name (protocol: Trust).
    let careful: Bool
    /// Whether the app opens at login, absent when the Mac cannot register it.
    let login: Bool?
    /// Whether `openspot` is on the path of a terminal.
    let link: Bool?
    /// The version of the downloaded update that waits to install.
    let update: String?
    /// The calls that a restart would stop.
    let calls: Int?
    let firstLaunch: Bool?

    /// The state as JSON, or with `frame` as one block of `key=value` lines (protocol: The openspot command).
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
