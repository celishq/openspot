import Foundation

enum AppSetting: String, CaseIterable {
    case panelKey = "panel-key", fixKey = "fix-key", restore = "restore-within", slow, login, link, theme

    static let name = "Openspot"

    var isKey: Bool {
        self == .panelKey || self == .fixKey
    }

    var isReserved: Bool {
        self != .theme
    }

    var title: String {
        switch self {
        case .panelKey: "Open Openspot"
        case .fixKey: "Open a fix"
        case .restore: "Keep your place"
        case .slow: "Slow motion"
        case .login: "Open at login"
        case .link: "Use openspot in Terminal"
        case .theme: "Theme"
        }
    }

    var detail: String? {
        switch self {
        case .slow: "Every motion ten times slower"
        case .restore: "How long a reopen after a click outside brings back where you were"
        case .link: "The command line tool"
        default: nil
        }
    }

    var icon: String {
        switch self {
        case .panelKey: "keyboard"
        case .fixKey: "wrench.and.screwdriver"
        case .restore: "arrow.uturn.backward"
        case .slow: "tortoise"
        case .login: "power"
        case .link: "terminal"
        case .theme: "paintpalette"
        }
    }

    var kind: SettingRow.Kind {
        switch self {
        case .panelKey, .fixKey: .key
        case .slow, .login, .link: .toggle
        case .restore, .theme: .choice
        }
    }

    var section: SettingsPage.Section {
        switch self {
        case .slow: .developer
        case .theme: .look
        case .panelKey, .fixKey, .restore, .login, .link: .general
        }
    }

    var options: [String] {
        self == .restore ? Config.restoreTimes.map(\.name) : []
    }

    static func rows(_ values: [AppSetting: String]) -> [SettingRow] {
        allCases.compactMap { setting in
            values[setting].map {
                SettingRow(spot: ReservedSetting.appSpot, name: name, key: setting.rawValue, title: setting.title, value: $0, kind: setting.kind, section: setting.section, icon: setting.icon, detail: setting.detail, options: setting.options)
            }
        }
    }
}
