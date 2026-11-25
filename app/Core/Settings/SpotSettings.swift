import Foundation

public struct SpotSettings: Equatable, Sendable {
    struct Key: Equatable, Sendable {
        let act: GlobalKey.Act
        let title: String
        let icon: String
    }

    static let menuBarKey = "menubar"
    static let windowKey = "window"
    static let menuBarIcon = "menubar.rectangle"
    static let windowIcon = "macwindow"
    static let valueIcon = "slider.horizontal.3"

    public let spot: String
    let fields: [Manifest.Setting]
    let showsInMenuBar: Bool
    let keys: [Key]
    var isWindowByDefault = false
    var opensAsWindow = false
    var name = ""

    private func kept(in config: Config) -> [SpotSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && Manifest.Setting.isKey(value.key) && !fields.contains { $0.id == value.key }
        }
    }

    func rows(in config: Config, secrets: [String: String]) -> [SettingRow] {
        func row(_ key: String, _ title: String, _ value: String?, _ kind: SettingRow.Kind, _ icon: String) -> SettingRow {
            SettingRow(spot: spot, name: name, key: key, title: title, value: value, kind: kind, section: .spot, icon: icon)
        }
        let keyRows = self.keys.map { key in row(key.act.setting, key.title, config.keys.first { $0.spot == spot && $0.act == key.act }?.trigger.text, .key, key.icon) }
        let fieldRows = self.fields.map { field in
            field.isSecret
                ? row(field.id, field.title, secrets[field.id].map { _ in SettingRow.secretValue }, .secret, Self.valueIcon)
                : row(field.id, field.title, config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : $0 }, Self.kind(of: field), Self.valueIcon)
        }
        let keptRows = kept(in: config).map { row($0.key, Manifest.Setting(id: $0.key).title, $0.value, .text, Self.valueIcon) }
        let menuBarRow = row(Self.menuBarKey, "Show in the menu bar", String(config.arrangement.menuBar.contains(spot)), .toggle, Self.menuBarIcon)
        let windowRow = row(Self.windowKey, "Open in a window", String(isWindow(in: config)), .toggle, Self.windowIcon)
        let placeRows = showsInMenuBar ? [menuBarRow] + (opensAsWindow ? [] : [windowRow]) : []
        return keyRows + fieldRows + keptRows + placeRows
    }

    private static func kind(of field: Manifest.Setting) -> SettingRow.Kind {
        if !field.options.isEmpty || field.parameter.type.kind == .choice { return .choice }
        return field.parameter.type.kind == .bool ? .toggle : .field
    }

    private func isWindow(in config: Config) -> Bool {
        config.arrangement.isWindow(of: spot) ?? isWindowByDefault
    }
}
