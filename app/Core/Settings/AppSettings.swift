import Foundation

struct AppSettings {
    static let themeKey = "theme"
    static let name = "Openspot"

    let panelKey: String
    let fixKey: String
    let slow: Bool?
    let login: Bool?
    let link: Bool?
    let theme: String

    var rows: [SettingRow] {
        let spot = ReservedSetting.appSpot
        func toggle(_ key: String, _ value: Bool?, _ title: String, _ icon: String, _ section: SettingRow.Section, _ detail: String? = nil) -> SettingRow? {
            value.map { SettingRow(spot: spot, name: Self.name, key: key, title: title, value: String($0), kind: .toggle, section: section, icon: icon, detail: detail) }
        }
        return [
            SettingRow(spot: spot, name: Self.name, key: "panel-key", title: "Open Openspot", value: panelKey, kind: .key, section: .general, icon: "keyboard"),
            SettingRow(spot: spot, name: Self.name, key: "fix-key", title: "Open a fix", value: fixKey, kind: .key, section: .general, icon: "wrench.and.screwdriver"),
            toggle("slow", slow, "Slow motion", "tortoise", .developer, "Every motion ten times slower"),
            toggle("login", login, "Open at login", "power", .general),
            toggle("link", link, "Use openspot in Terminal", "terminal", .general, "The command line tool"),
            SettingRow(spot: spot, name: Self.name, key: Self.themeKey, title: "Theme", value: theme, kind: .choice, section: .look, icon: "paintpalette")
        ].compactMap { $0 }
    }
}
