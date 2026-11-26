import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let icon = "icon"
    static let attachment = "attachment"
    private static let choiceKeys: Set<String> = ["grid", "search", "enabled", "global", "tray"]
    private static let spotKeys: Set<String> = choiceKeys.union([SpotRows.menuBarKey, SpotRows.windowKey, icon, attachment])
    static let appKeys = Set(AppSetting.allCases.filter(\.isReserved).map(\.rawValue))

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || GlobalKey.Act(setting: key) != nil
    }
}
