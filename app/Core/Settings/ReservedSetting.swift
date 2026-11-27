import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let icon = "icon"
    static let hiddenAttachment = "false"
    static let choiceKeys: Set<String> = ["grid", "search", "enabled", "global", "tray"]
    private static let spotKeys: Set<String> = choiceKeys.union(SpotPlace.allCases.map(\.key) + [icon])
    static let appKeys = Set(AppSetting.allCases.filter(\.isReserved).map(\.rawValue))

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || GlobalKey.Act(setting: key) != nil
    }
}
