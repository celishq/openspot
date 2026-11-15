import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let commandKey = "key."
    static let icon = "icon"
    private static let spotKeys: Set<String> = ["enabled", "menubar", "float", icon]
    static let appKeys: Set<String> = ["login", "link", "careful", "panel-key", "fix-key"]

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || key.hasPrefix(commandKey)
    }
}
