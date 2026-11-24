import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let icon = "icon"
    private static let spotKeys: Set<String> = ["enabled", "menubar", icon]
    static let appKeys: Set<String> = ["login", "link", "careful", "slow", "panel-key", "fix-key"]

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || GlobalKey.Act(setting: key) != nil
    }
}
