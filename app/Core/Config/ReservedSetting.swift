import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let commandKey = "key."
    static let icon = "icon"
    private static let spotKeys: Set<String> = ["enabled", "menubar", "open", "float", icon]
    static let appKeys: Set<String> = ["login", "link", "careful", "panel-key", "fix-key"]

    static func act(of key: String) -> GlobalKey.Act? {
        switch key {
        case "open": .open
        case "float": .float
        case let key where key.hasPrefix(commandKey): .command(String(key.dropFirst(commandKey.count)))
        default: nil
        }
    }

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || key.hasPrefix(commandKey)
    }
}
