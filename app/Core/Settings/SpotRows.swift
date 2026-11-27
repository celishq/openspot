import Foundation

public struct SpotRows: Equatable, Sendable {
    struct Key: Equatable, Sendable {
        let act: GlobalKey.Act
        let title: String
        let icon: String
    }

    static let valueIcon = "slider.horizontal.3"

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
        let placeRows = places.map { place in row(place.key, place.title, String(isShown(in: place, config)), .toggle, place.icon) }
        return keyRows + fieldRows + keptRows + placeRows
    }

    private static func kind(of field: Manifest.Setting) -> SettingRow.Kind {
        if !field.options.isEmpty || field.parameter.type.kind == .choice { return .choice }
        return field.parameter.type.kind == .bool ? .toggle : .field
    }

    private var places: [SpotPlace] {
        SpotPlace.allCases.filter { $0 == .searchField ? isAttachmentSource : showsInMenuBar }
    }

    private func isShown(in place: SpotPlace, _ config: Config) -> Bool {
        switch place {
        case .searchField: !config.hidesAttachment(of: spot)
        case .menuBar: config.arrangement.menuBar.contains(spot)
        case .window: isWindow(in: config)
        }
    }

    private func isWindow(in config: Config) -> Bool {
        config.arrangement.isWindow(of: spot) ?? isWindowByDefault
    }
}
