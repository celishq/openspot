import AppKit
import OpenspotCore
import SwiftUI

extension SpotTheme {
    static let settingsRim = 0.08
    static let settingsQuietFill = 0.06
    static let settingsQuieterFill = 0.04
    static let settingsCapRim = 0.3
    static let settingsStepFill = 0.12
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
    static let settingsBarFade = [Color.black, Color.clear]
    static let settingsSelection = Color(nsColor: .controlAccentColor)
    static let settingsSelectedInk = Color.white
    static let settingsLookCell = 0.12
    static let settingsLookHint = 0.5
    static let settingsLookPanelFill = 0.92
    static let settingsLookCards = ["plus.forwardslash.minus", "face.smiling", "party.popper", "doc.on.clipboard"]
    static let settingsLookWall = 0.35

    static let settingsSpotColours: [Color] = [.blue, .indigo, .purple, .pink, .red, .orange, .yellow, .green, .mint, .teal, .cyan, .brown, .gray]

    static let storeMine = Color.blue
    static let storeDropFill = 0.25

    static func storeSource(_ source: StoreSource) -> Color {
        source.isBuiltIn ? .purple : .gray
    }

    static func settingsSpot(_ id: String) -> Color {
        settingsSpotColours[id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % settingsSpotColours.count]
    }

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

    static func settings(_ status: AccessStatus) -> Color {
        switch status {
        case .denied: .red
        case .unasked: .orange
        default: .secondary
        }
    }

    static func settingsState(_ readiness: SpotReadiness) -> Color {
        readiness == .ready ? settingsDone : settingsLate
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
