import Foundation

/// What `openspot app status` prints as JSON. A value that only the running app knows is absent in a process of its own.
struct AppStatus: Encodable {
    let version: String
    let panelKey: String
    let fixKey: String
    /// Whether the app opens at login, absent when the Mac cannot register it.
    let login: Bool?
    /// Whether `openspot` is on the path of a terminal.
    let link: Bool?
    /// The version of the downloaded update that waits to install.
    let update: String?
    /// The calls that a restart would stop.
    let calls: Int?
    let firstLaunch: Bool?

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
    }
}
