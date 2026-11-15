import Foundation

public struct SpotSettings: Equatable, Sendable {
    enum Row: Equatable {
        case key(String)
        case float
        case menuBar
        case setting(String)

        init?(id: String, of spot: String) {
            let named = { (word: String) in id.hasPrefix("\(word):\(spot):") ? String(id.dropFirst(word.count + spot.count + 2)) : nil }
            if let command = named("key") {
                self = .key(command)
            } else if let key = named("setting") {
                self = .setting(key)
            } else if id == "float:\(spot)" {
                self = .float
            } else if id == "menubar:\(spot)" {
                self = .menuBar
            } else {
                return nil
            }
        }

        func id(of spot: String) -> String {
            switch self {
            case .key(let command): "key:\(spot):\(command)"
            case .float: "float:\(spot)"
            case .menuBar: "menubar:\(spot)"
            case .setting(let key): "setting:\(spot):\(key)"
            }
        }
    }

    private static let clear = removeID
    public static let removeID = "clear"
    private static let open = "open"
    static let soleTitle = "shortcut"
    public static let unset = "Record"
    static let secretWord = "Set, and hidden"
    static let menuBarIcon = "menubar.rectangle"
    static let floatIcon = "pip"
    static let keyIcon = "keyboard"
    static let valueIcon = "slider.horizontal.3"

    public static func keyRun(spot: String, command: String) -> String {
        Row.key(command).id(of: spot)
    }

    public static func sheetID(of spot: String) -> String {
        OwnedSheet.settings.id(of: spot)
    }

    public static func owner(of sheetID: String) -> String? {
        OwnedSheet.owner(of: sheetID).flatMap { $0.sheet == .settings ? $0.spot : nil }
    }

    public let file: ConfigFile
    public let spot: String
    let offers: [CommandOffer]
    let fields: [CommandOffer]
    let offersFloat: Bool
    let showsInMenuBar: Bool

    public func hasRows(in config: Config) -> Bool {
        showsInMenuBar || offersFloat || !offers.isEmpty || !fields.isEmpty || !kept(in: config).isEmpty
    }

    public func field(of run: String) -> String? {
        guard case .setting(let key) = row(run) else { return nil }
        return key
    }

    func answer(_ arguments: [String]) throws -> String {
        let row = arguments.dropFirst().first
        switch (arguments.first, row.flatMap(self.row)) {
        case ("read", _):
            return sheet(in: file.read())
        case (Self.clear, let found?):
            try clear(found)
            return ""
        case (Self.open, .menuBar):
            try file.change { $0.arrangement.set(isInMenuBar: !$0.arrangement.menuBar.contains(spot), of: spot) }
            return ""
        case (let run?, _) where command(of: run) != nil || self.row(run) == .float:
            guard let trigger = row.flatMap(Trigger.init(text:)) else { throw SpotError.failed(1, "Openspot cannot use this key.") }
            try file.change { $0.assign(trigger, to: spot, act: command(of: run).map(GlobalKey.Act.command) ?? .float) }
            return ""
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private func row(_ id: String) -> Row? {
        guard let row = Row(id: id, of: spot) else { return nil }
        if case .key(let command) = row, !offers.contains(where: { $0.id == command }) { return nil }
        return row
    }

    private func command(of id: String) -> String? {
        guard case .key(let command) = row(id) else { return nil }
        return command
    }

    private func clear(_ row: Row) throws {
        switch row {
        case .key(let command): try file.change { $0.assign(nil, to: spot, act: .command(command)) }
        case .float: try file.change { $0.assign(nil, to: spot, act: .float) }
        case .menuBar: try file.change { $0.arrangement.set(isInMenuBar: false, of: spot) }
        case .setting(let key): try file.change { $0.set(setting: key, of: spot, to: nil) }
        }
    }

    private func kept(in config: Config) -> [SpotSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && CommandOffer(setting: value.key) != nil && !fields.contains { $0.id == value.key }
        }
    }

    func sheet(in config: Config) -> String {
        var blocks = [
            TextBlock(fields: [.init(key: "recents", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.open), .init(key: "title", value: "Change"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.clear), .init(key: "title", value: "Remove"), .init(key: "shortcut", value: "cmd+backspace")])
        ]
        let named = fields.map { field in (field, config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : field.isSecret ? Self.secretWord : $0 }) }
        let kept = kept(in: config).compactMap { value in CommandOffer(setting: value.key).map { ($0, Optional(value.value)) } }
        blocks += (named + kept).map(fieldRow)
        blocks += keyRows(config.keys)
        if offersFloat {
            let key = config.keys.first { $0.spot == spot && $0.act == .float }
            blocks.append(keyRow(.float, title: "Float", detail: [], icon: Self.floatIcon, key: key))
        }
        if showsInMenuBar {
            blocks.append(TextBlock(fields: [
                .init(key: "row", value: Row.menuBar.id(of: spot)), .init(key: "title", value: "Show in the menu bar"), .init(key: "icon", value: Self.menuBarIcon),
                .init(key: "hides", value: Self.clear), .init(key: "value", value: String(config.arrangement.menuBar.contains(spot)))
            ]))
        }
        return blocks.map(\.text).joined(separator: "\n")
    }

    private func fieldRow(_ field: CommandOffer, _ value: String?) -> TextBlock {
        TextBlock(fields: [
            .init(key: "row", value: Row.setting(field.id).id(of: spot)), .init(key: "title", value: field.title),
            .init(key: "detail", value: value ?? "Not set"), .init(key: "icon", value: Self.valueIcon)
        ] + (value == nil ? [.init(key: "hides", value: Self.clear)] : []))
    }

    private func keyRows(_ keys: [GlobalKey]) -> [TextBlock] {
        let isSole = offers.count == 1
        return offers.map { offer in
            let key = keys.first { $0.spot == spot && $0.act == .command(offer.id) }
            let detail: [TextBlock.Field] = !isSole ? [] : key == nil
                ? [.init(key: "detail", value: "Press ⏎ to set")]
                : [.init(key: "detail", value: "Press ⌘↓ to select"), .init(key: "focus", value: "Press ⏎ to change")]
            let title = isSole ? "\(offer.title) \(Self.soleTitle)" : offer.title
            return keyRow(.key(offer.id), title: title, detail: detail, icon: Self.keyIcon, key: key)
        }
    }

    private func keyRow(_ row: Row, title: String, detail: [TextBlock.Field], icon: String, key: GlobalKey?) -> TextBlock {
        TextBlock(fields: [.init(key: "row", value: row.id(of: spot)), .init(key: "title", value: title)] + detail + [.init(key: "icon", value: icon)]
            + (key == nil ? [.init(key: "hides", value: Self.clear)] : [])
            + [.init(key: "type", value: "hotkey"), .init(key: "shake", value: "true"), .init(key: "shortcut", value: key?.trigger.text ?? Self.unset)])
    }
}
