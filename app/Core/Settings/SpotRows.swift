import Foundation

public struct SpotRows: Equatable, Sendable {
    struct Key: Equatable, Sendable {
        let act: GlobalKey.Act
        let title: String
        let icon: String
    }

    public static let menuBarKey = "menubar"
    public static let windowKey = "window"
    static let menuBarIcon = "menubar.rectangle"
    static let windowIcon = "macwindow"
    static let valueIcon = "slider.horizontal.3"
    static let attachmentIcon = "paperclip"
    static let attachmentTitle = "Show beside the search field"
    static let attachmentLine = "Tab hands what shows beside the search field to a spot."
    static let placeKeys = [ReservedSetting.attachment, menuBarKey, windowKey]

    public static func placeName(of key: String) -> String? {
        switch key {
        case ReservedSetting.attachment: "Search Field"
        case menuBarKey: "Menu Bar"
        case windowKey: "Window"
        default: nil
        }
    }

    public let spot: String
    let fields: [Manifest.Setting]
    let showsInMenuBar: Bool
    let keys: [Key]
    let isWindowByDefault: Bool
    let name: String
    let isAttachmentSource: Bool

    private func kept(in config: Config) -> [KeptSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && Manifest.Setting.isKey(value.key) && !fields.contains { $0.id == value.key }
        }
    }

    func rows(in config: Config, secrets: [String: String]) -> [SettingRow] {
        func row(_ key: String, _ title: String, _ value: String?, _ kind: SettingRow.Kind, _ icon: String) -> SettingRow {
            SettingRow(spot: spot, name: name, key: key, title: title, value: value, kind: kind, section: nil, icon: icon)
        }
        let keyRows = self.keys.map { key in row(key.act.setting, key.title, config.keys.first { $0.spot == spot && $0.act == key.act }?.trigger.text, .key, key.icon) }
        let fieldRows = self.fields.map { field in
            field.isSecret
                ? row(field.id, field.title, secrets[field.id].map { _ in SettingRow.secretValue }, .secret, Self.valueIcon)
                : SettingRow(
                    spot: spot, name: name, key: field.id, title: field.title, value: config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : $0 }, kind: Self.kind(of: field),
                    section: nil, icon: Self.valueIcon, options: field.options, default: field.defaultValue
                )
        }
        let keptRows = kept(in: config).map { row($0.key, Manifest.Setting(id: $0.key).title, $0.value, .text, Self.valueIcon) }
        let attachmentRow = SettingRow(spot: spot, name: name, key: ReservedSetting.attachment, title: Self.attachmentTitle, value: String(!config.hidesAttachment(of: spot)), kind: .toggle, section: nil, icon: Self.attachmentIcon, detail: Self.attachmentLine)
        let sourceRows = isAttachmentSource ? [attachmentRow] : []
        let menuBarRow = row(Self.menuBarKey, "Show in the menu bar", String(config.arrangement.menuBar.contains(spot)), .toggle, Self.menuBarIcon)
        let windowRow = row(Self.windowKey, "Open in a window", String(isWindow(in: config)), .toggle, Self.windowIcon)
        let placeRows = showsInMenuBar ? [menuBarRow, windowRow] : []
        return keyRows + fieldRows + keptRows + sourceRows + placeRows
    }

    private static func kind(of field: Manifest.Setting) -> SettingRow.Kind {
        if !field.options.isEmpty || field.parameter.type.kind == .choice { return .choice }
        return field.parameter.type.kind == .bool ? .toggle : .field
    }

    private func isWindow(in config: Config) -> Bool {
        config.arrangement.isWindow(of: spot) ?? isWindowByDefault
    }
}
