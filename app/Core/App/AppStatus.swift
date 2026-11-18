import Foundation

struct AppStatus: PrintedRecord {
    let version: String
    let panelKey: String
    let fixKey: String
    let careful: Bool
    let slow: Bool?
    let login: Bool?
    let link: Bool?
    let update: String?
    let calls: Int?
    let firstLaunch: Bool?

    private enum CodingKeys: String, CodingKey {
        case version
        case panelKey = "panel-key"
        case fixKey = "fix-key"
        case careful, slow, login, link, update, calls, firstLaunch
    }

    var blocks: [[(String, String?)]] {
        [[
            ("text", "status"), ("version", version), (CodingKeys.panelKey.rawValue, panelKey), (CodingKeys.fixKey.rawValue, fixKey), ("careful", String(careful)), ("slow", slow.map(String.init)), ("login", login.map(String.init)), ("link", link.map(String.init)),
            ("update", update), ("calls", calls.map(String.init)), ("firstLaunch", firstLaunch.map(String.init))
        ]]
    }
}
