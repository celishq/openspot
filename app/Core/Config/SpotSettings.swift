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
    private static let open = "open"
    static let secretWord = "Set, and hidden"
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

    func answer(_ arguments: [String]) throws -> String {
        let row = arguments.dropFirst().first
        switch (arguments.first, row.flatMap(self.row)) {
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
        case (let id?, nil) where arguments.count == 2:
            guard case .key(let act)? = self.row(id), keys.contains(where: { $0.act == act }) else { throw SpotError.failed(1, "This sheet cannot do that.") }
            guard let trigger = Trigger(text: arguments[1]) else {
                throw SpotError.failed(1, "Openspot cannot use `\(arguments[1])`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab, or use shake.")
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

    func sheet(in config: Config, secrets: [String: String]) -> String {
        var blocks = [
            RootKey.block([.init(key: "recents", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.open), .init(key: "title", value: "Change"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.clear), .init(key: "title", value: "Remove"), .init(key: "shortcut", value: "cmd+backspace"), .init(key: "close", value: "false")])
        ]
        blocks += keys.map { key in keyRow(key, config.keys.first { $0.spot == spot && $0.act == key.act }) }
        let named = fields.map { field in
            (field, field.isSecret ? secrets[field.id].map { _ in Self.secretWord } : config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : $0 })
        }
        let kept = kept(in: config).map { value in (Manifest.Setting(id: value.key), Optional(value.value)) }
        blocks += (named + kept).map(fieldRow)
        if showsInMenuBar {
            blocks.append(TextBlock(fields: [
                .init(key: "item", value: Row.menuBar.id(of: spot)), .init(key: "title", value: "Show in the menu bar"), .init(key: "icon", value: Self.menuBarIcon),
                .init(key: "hides", value: Self.clear), .init(key: "value", value: String(config.arrangement.menuBar.contains(spot)))
            ]))
            blocks.append(TextBlock(fields: [
                .init(key: "item", value: Row.window.id(of: spot)), .init(key: "title", value: "Open in a window"), .init(key: "icon", value: Self.windowIcon),
                .init(key: "hides", value: Self.clear), .init(key: "value", value: String(isWindow(in: config)))
            ]))
        }
        return blocks.map(\.text).joined(separator: "\n")
    }

    private func isWindow(in config: Config) -> Bool {
        config.arrangement.isWindow(of: spot) ?? isWindowByDefault
    }

    private func keyRow(_ key: Key, _ given: GlobalKey?) -> TextBlock {
        let text = given?.trigger.text
        return TextBlock(fields: [
            .init(key: "field", value: Row.key(key.act).id(of: spot)), .init(key: "type", value: "hotkey"), .init(key: "title", value: key.title),
            .init(key: "icon", value: key.icon), .init(key: "shake", value: "true"), .init(key: "close", value: "false")
        ] + (text.map { [.init(key: "value", value: $0)] } ?? [.init(key: "detail", value: Self.unsetKey), .init(key: "hides", value: Self.clear)]))
    }

    private func fieldRow(_ field: Manifest.Setting, _ value: String?) -> TextBlock {
        TextBlock(fields: [
            .init(key: "item", value: Row.setting(field.id).id(of: spot)), .init(key: "title", value: field.title),
            .init(key: "detail", value: value ?? "Not set"), .init(key: "icon", value: Self.valueIcon)
        ] + (value == nil ? [.init(key: "hides", value: Self.clear)] : []))
    }
}
