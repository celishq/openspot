import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    static let icon = "icon"
    private static let spotKeys: Set<String> = ["enabled", SpotRows.menuBarKey, SpotRows.windowKey, icon]
    static let appKeys = Set(AppSetting.allCases.filter(\.isReserved).map(\.rawValue))

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || GlobalKey.Act(setting: key) != nil
    }
}
