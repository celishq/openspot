import OpenspotCore
import SwiftUI

extension SpotTheme {
    static let settingsFill = 0.045
    static let settingsRim = 0.08
    static let settingsQuietFill = 0.06
    static let settingsQuieterFill = 0.04
    static let settingsIconFill = 0.08
    static let settingsCapRim = 0.3
    static let settingsStepFill = 0.12
    static let settingsBannerFill = 0.12
    static let settingsBannerRim = 0.45
    static let settingsTarget = 0.15
    static let settingsDim = Color.black.opacity(0.18)
    static let settingsSheetShadow = Color.black.opacity(0.25)
    static let settingsBadge = Color.red
    static let settingsBadgeInk = Color.white
    static let settingsTileInk = Color.white
    static let settingsLate = Color.orange
    static let settingsClash = Color.red
    static let settingsDone = Color.green
    static let settingsAccountTile = Color.gray
    static let settingsLookInk = 0.18
    static let settingsLookCell = 0.14
    static let settingsLookPanel = 0.88
    static let settingsLookWall = [
        Color(red: 0.96, green: 0.36, blue: 0.36), Color(red: 0.55, green: 0.42, blue: 0.95), Color(red: 0.36, green: 0.78, blue: 0.42)
    ]

    static func settings(_ section: SettingsPage.Section) -> Color {
        switch section {
        case .access: .blue
        case .spots: .purple
        case .keys: .gray
        case .look: Color(white: 0.15)
        case .account: .indigo
        case .general: .gray
        case .developer: Color(white: 0.3)
        }
    }

    static func settings(_ access: MacAccess) -> Color {
        switch access {
        case .accessibility: Color(red: 0.10, green: 0.49, blue: 0.96)
        case .automation: Color(red: 0.56, green: 0.56, blue: 0.58)
        case .screen: Color(red: 0.65, green: 0.31, blue: 0.94)
        case .calendars: Color(red: 1, green: 0.23, blue: 0.19)
        case .reminders: Color(red: 1, green: 0.58, blue: 0)
        case .camera: Color(red: 0.19, green: 0.64, blue: 0.42)
        case .microphone: Color(red: 1, green: 0.18, blue: 0.33)
        case .input: Color(red: 0.39, green: 0.39, blue: 0.40)
        case .helper: Color(red: 0.96, green: 0.71, blue: 0)
        }
    }

    static func settings(_ status: ReadAccess) -> Color {
        switch status {
        case .denied: .red
        case .unasked: .orange
        default: .secondary
        }
    }

    static func settingsTone(_ word: String?) -> Color {
        switch word {
        case "good": .green
        case "warn": .orange
        case "bad": .red
        default: .secondary
        }
    }
}
