import Foundation

public struct SpotSettings: Equatable, Sendable {
    struct Key: Equatable, Sendable {
        let act: GlobalKey.Act
        let title: String
        let icon: String
    }

    enum Row: Equatable {
        case key(GlobalKey.Act)
        case menuBar
        case window
        case setting(String)

        init(key: String) {
            if let act = GlobalKey.Act(setting: key) {
                self = .key(act)
            } else if key == SpotSettings.menuBarKey {
                self = .menuBar
            } else if key == SpotSettings.windowKey {
                self = .window
            } else {
                self = .setting(key)
            }
        }

        init?(id: String, of spot: String) {
            let named = { (word: String) in id.hasPrefix("\(word):\(spot):") ? String(id.dropFirst(word.count + spot.count + 2)) : nil }
            if let act = named("key").flatMap(GlobalKey.Act.init(setting:)) {
                self = .key(act)
            } else if let key = named("setting") {
                self = .setting(key)
            } else if id == "menubar:\(spot)" {
                self = .menuBar
            } else if id == "window:\(spot)" {
                self = .window
            } else {
                return nil
            }
        }

        func id(of spot: String) -> String {
            switch self {
            case .key(let act): "key:\(spot):\(act.setting)"
            case .menuBar: "menubar:\(spot)"
            case .window: "window:\(spot)"
            case .setting(let key): "setting:\(spot):\(key)"
            }
        }
    }

    private static let clear = removeID
    public static let removeID = "clear"
    private static let open = ScriptEntry.press.name
    static let secretWord = "Set, and hidden"
    static let menuBarKey = "menubar"
    static let windowKey = "window"
    static let menuBarIcon = "menubar.rectangle"
    static let windowIcon = "macwindow"
    static let valueIcon = "slider.horizontal.3"
    static let unsetKey = "Press ⏎ to set"

    public static func sheetID(of spot: String) -> String {
        OwnedSheet.settings.id(of: spot)
    }

    public static func owner(of sheetID: String) -> String? {
        OwnedSheet.owner(of: sheetID).flatMap { $0.sheet == .settings ? $0.spot : nil }
    }

    public let file: ConfigFile
    let secrets: SecretStore
    public let spot: String
    let fields: [Manifest.Setting]
    let showsInMenuBar: Bool
    let keys: [Key]
    var isWindowByDefault = false

    public func hasRows(in config: Config) -> Bool {
        !keys.isEmpty || showsInMenuBar || !fields.isEmpty || !kept(in: config).isEmpty
    }

    public func field(of run: String) -> String? {
        guard case .setting(let key) = row(run) else { return nil }
        return key
    }

    func answer(_ arguments: [String], input: String? = nil) throws -> String {
        let fields = TextBlock.blocks(in: input ?? "").first
        let value = fields?.value("input.value")
        switch (arguments.first, fields?.value("input.item").flatMap(self.row)) {
        case ("show", _):
            return sheet(in: file.read(), secrets: try secrets.read()[spot] ?? [:])
        case (Self.clear, let found?):
            try clear(found)
            return ""
        case (Self.open, .menuBar):
            try file.change { $0.arrangement.set(isInMenuBar: !$0.arrangement.menuBar.contains(spot), of: spot) }
            return ""
        case (Self.open, .window):
            try file.change { $0.arrangement.set(isWindow: !isWindow(in: $0), of: spot) }
            return ""
        case (let id?, nil) where value != nil:
            guard case .key(let act)? = self.row(id), keys.contains(where: { $0.act == act }), let value else { throw SpotError.failed(1, "This sheet cannot do that.") }
            guard let trigger = Trigger(text: value) else {
                throw SpotError.failed(1, "Openspot cannot use `\(value)`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab, or use shake.")
            }
            try file.change { $0.assign(trigger, to: spot, act: act) }
            return ""
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private func row(_ id: String) -> Row? {
        Row(id: id, of: spot)
    }

    private func clear(_ row: Row) throws {
        switch row {
        case .key(let act): try file.change { $0.assign(nil, to: spot, act: act) }
        case .menuBar: try file.change { $0.arrangement.set(isInMenuBar: false, of: spot) }
        case .window: try file.change { $0.arrangement.set(isWindow: false, of: spot) }
        case .setting(let key) where fields.contains { $0.id == key && $0.isSecret }: try secrets.keep(nil, key: key, of: spot)
        case .setting(let key): try file.change { $0.set(setting: key, of: spot, to: nil) }
        }
    }

    private func kept(in config: Config) -> [SpotSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && Manifest.Setting.isKey(value.key) && !fields.contains { $0.id == value.key }
        }
    }

    func rows(in config: Config, secrets: [String: String]) -> [SettingRow] {
        func row(_ key: String, _ title: String, _ value: String?, _ kind: SettingRow.Kind, _ icon: String) -> SettingRow {
            SettingRow(spot: spot, key: key, title: title, value: value, kind: kind, section: .spot, icon: icon)
        }
        let keyRows = self.keys.map { key in row(key.act.setting, key.title, config.keys.first { $0.spot == spot && $0.act == key.act }?.trigger.text, .key, key.icon) }
        let fieldRows = self.fields.map { field in
            field.isSecret
                ? row(field.id, field.title, secrets[field.id].map { _ in SettingRow.secretValue }, .secret, Self.valueIcon)
                : row(field.id, field.title, config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : $0 }, Self.kind(of: field), Self.valueIcon)
        }
        let keptRows = kept(in: config).map { row($0.key, Manifest.Setting(id: $0.key).title, $0.value, .text, Self.valueIcon) }
        let placeRows = showsInMenuBar ? [
            row(Self.menuBarKey, "Show in the menu bar", String(config.arrangement.menuBar.contains(spot)), .toggle, Self.menuBarIcon),
            row(Self.windowKey, "Open in a window", String(isWindow(in: config)), .toggle, Self.windowIcon)
        ] : []
        return keyRows + fieldRows + keptRows + placeRows
    }

    private static func kind(of field: Manifest.Setting) -> SettingRow.Kind {
        if !field.options.isEmpty || field.parameter.type.kind == .choice { return .choice }
        return field.parameter.type.kind == .bool ? .toggle : .field
    }

    func sheet(in config: Config, secrets: [String: String]) -> String {
        let blocks = [
            RootKey.block([.init(key: "recents", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.open), .init(key: "title", value: "Change"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.clear), .init(key: "title", value: "Remove"), .init(key: "shortcut", value: "cmd+backspace"), .init(key: "close", value: "false")])
        ] + rows(in: config, secrets: secrets).map(block(of:))
        return blocks.map(\.text).joined(separator: "\n")
    }

    private func isWindow(in config: Config) -> Bool {
        config.arrangement.isWindow(of: spot) ?? isWindowByDefault
    }

    private func block(of row: SettingRow) -> TextBlock {
        switch Row(key: row.key) {
        case .key(let act): keyRow(act, row)
        case .menuBar, .window: placeRow(row)
        case .setting: fieldRow(row)
        }
    }

    private func keyRow(_ act: GlobalKey.Act, _ row: SettingRow) -> TextBlock {
        TextBlock(fields: [
            .init(key: "field", value: Row.key(act).id(of: spot)), .init(key: "type", value: "hotkey"), .init(key: "title", value: row.title),
            .init(key: "icon", value: row.icon), .init(key: "shake", value: "true"), .init(key: "close", value: "false")
        ] + (row.value.map { [.init(key: "value", value: $0)] } ?? [.init(key: "detail", value: Self.unsetKey), .init(key: "hides", value: Self.clear)]))
    }

    private func placeRow(_ row: SettingRow) -> TextBlock {
        TextBlock(fields: [
            .init(key: "item", value: Row(key: row.key).id(of: spot)), .init(key: "title", value: row.title), .init(key: "icon", value: row.icon),
            .init(key: "hides", value: Self.clear), .init(key: "value", value: row.value ?? "false")
        ])
    }

    private func fieldRow(_ row: SettingRow) -> TextBlock {
        let shown = row.kind == .secret ? row.value.map { _ in Self.secretWord } : row.value
        return TextBlock(fields: [
            .init(key: "item", value: Row(key: row.key).id(of: spot)), .init(key: "title", value: row.title),
            .init(key: "detail", value: shown ?? "Not set"), .init(key: "icon", value: row.icon)
        ] + (shown == nil ? [.init(key: "hides", value: Self.clear)] : []))
    }
}
