import Foundation

public struct SpotSettings: Equatable, Sendable {
    enum Row: Equatable {
        case menuBar
        case setting(String)

        init?(id: String, of spot: String) {
            let named = { (word: String) in id.hasPrefix("\(word):\(spot):") ? String(id.dropFirst(word.count + spot.count + 2)) : nil }
            if let key = named("setting") {
                self = .setting(key)
            } else if id == "menubar:\(spot)" {
                self = .menuBar
            } else {
                return nil
            }
        }

        func id(of spot: String) -> String {
            switch self {
            case .menuBar: "menubar:\(spot)"
            case .setting(let key): "setting:\(spot):\(key)"
            }
        }
    }

    private static let clear = removeID
    public static let removeID = "clear"
    private static let open = "open"
    static let secretWord = "Set, and hidden"
    static let menuBarIcon = "menubar.rectangle"
    static let valueIcon = "slider.horizontal.3"

    public static func sheetID(of spot: String) -> String {
        OwnedSheet.settings.id(of: spot)
    }

    public static func owner(of sheetID: String) -> String? {
        OwnedSheet.owner(of: sheetID).flatMap { $0.sheet == .settings ? $0.spot : nil }
    }

    public let file: ConfigFile
    let secrets: SecretStore
    public let spot: String
    let fields: [CommandOffer]
    let showsInMenuBar: Bool

    public func hasRows(in config: Config) -> Bool {
        showsInMenuBar || !fields.isEmpty || !kept(in: config).isEmpty
    }

    public func field(of run: String) -> String? {
        guard case .setting(let key) = row(run) else { return nil }
        return key
    }

    func answer(_ arguments: [String]) throws -> String {
        let row = arguments.dropFirst().first
        switch (arguments.first, row.flatMap(self.row)) {
        case ("read", _):
            return sheet(in: file.read(), secrets: try secrets.read()[spot] ?? [:])
        case (Self.clear, let found?):
            try clear(found)
            return ""
        case (Self.open, .menuBar):
            try file.change { $0.arrangement.set(isInMenuBar: !$0.arrangement.menuBar.contains(spot), of: spot) }
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
        case .menuBar: try file.change { $0.arrangement.set(isInMenuBar: false, of: spot) }
        case .setting(let key) where fields.contains { $0.id == key && $0.isSecret }: try secrets.keep(nil, key: key, of: spot)
        case .setting(let key): try file.change { $0.set(setting: key, of: spot, to: nil) }
        }
    }

    private func kept(in config: Config) -> [SpotSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && CommandOffer(setting: value.key) != nil && !fields.contains { $0.id == value.key }
        }
    }

    func sheet(in config: Config, secrets: [String: String]) -> String {
        var blocks = [
            TextBlock(fields: [.init(key: "recents", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.open), .init(key: "title", value: "Change"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.clear), .init(key: "title", value: "Remove"), .init(key: "shortcut", value: "cmd+backspace")])
        ]
        let named = fields.map { field in
            (field, field.isSecret ? secrets[field.id].map { _ in Self.secretWord } : config.setting(field.id, of: spot).flatMap { $0.isEmpty ? nil : $0 })
        }
        let kept = kept(in: config).compactMap { value in CommandOffer(setting: value.key).map { ($0, Optional(value.value)) } }
        blocks += (named + kept).map(fieldRow)
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
}
