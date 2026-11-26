import Foundation

public enum SettingsMark: Hashable, Sendable {
    case section(SettingsPage.Section)
    case spot(String)
}
