import Foundation

public struct SpotSettings: Equatable, Sendable {
    private static let keyPrefix = "key:"
    private static let floatPrefix = "float:"
    private static let menuBarPrefix = "menubar:"
    private static let settingPrefix = "setting:"
    private static let clear = removeID
    public static let removeID = "clear"
    private static let open = "open"
    static let soleTitle = "shortcut"
    public static let unset = "Record"
    static let menuBarIcon = "menubar.rectangle"
    static let floatIcon = "pip"
    static let keyIcon = "keyboard"
    static let valueIcon = "slider.horizontal.3"

    public static func keyRun(spot: String, command: String) -> String {
        "\(keyPrefix)\(spot):\(command)"
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
        let prefix = "\(Self.settingPrefix)\(spot):"
        return run.hasPrefix(prefix) ? String(run.dropFirst(prefix.count)) : nil
    }


    func answer(_ arguments: [String]) throws -> String {
        let row = arguments.dropFirst().first
        switch arguments.first {
        case "read":
            return sheet
        case Self.clear where row.map(isRow) == true:
            try clear(row ?? "")
            return ""
        case Self.open where row == menuBarRun:
            try file.change { $0.arrangement.set(isInMenuBar: !$0.arrangement.menuBar.contains(spot), of: spot) }
            return ""
        case let run? where command(of: run) != nil || run == floatRun:
            guard let trigger = row.flatMap(Trigger.init(text:)) else { throw SpotError.failed(1, "Openspot cannot use this key.") }
            try file.change { $0.assign(trigger, to: spot, act: command(of: run).map(GlobalKey.Act.command) ?? .float) }
            return ""
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private func clear(_ run: String) throws {
        if let command = command(of: run) {
            try file.change { $0.assign(nil, to: spot, act: .command(command)) }
        } else if run == floatRun {
            try file.change { $0.assign(nil, to: spot, act: .float) }
        } else if run == menuBarRun {
            try file.change { $0.arrangement.set(isInMenuBar: false, of: spot) }
        } else if let key = field(of: run) {
            try file.change { $0.set(setting: key, of: spot, to: nil) }
        }
    }

    private var floatRun: String {
        "\(Self.floatPrefix)\(spot)"
    }

    private var menuBarRun: String {
        "\(Self.menuBarPrefix)\(spot)"
    }

    private func isRow(_ run: String) -> Bool {
        command(of: run) != nil || run == floatRun || run == menuBarRun || field(of: run) != nil
    }

    private func kept(in config: Config) -> [SpotSetting] {
        config.settings.filter { value in
            value.spot == spot && !ReservedSetting.isReserved(value.key) && CommandOffer(setting: value.key) != nil && !fields.contains { $0.id == value.key }
        }
    }

    private var sheet: String {
        let config = file.read()
        let actions = ["recents=false\n", "button=open\ntitle=Change\nclose=false\n", "button=\(Self.clear)\ntitle=Remove\nshortcut=cmd+backspace\n"]
        let named = fields.map { ($0, config.setting($0.id, of: spot).flatMap { $0.isEmpty ? nil : $0 }) }
        let kept = kept(in: config).compactMap { value in CommandOffer(setting: value.key).map { ($0, Optional(value.value)) } }
        let values = named + kept
        var rows = values.map(fieldRow)
        rows += keyRows(config.keys)
        if offersFloat {
            let key = config.keys.first { $0.spot == spot && $0.act == .float }
            rows.append(keyRow(run: floatRun, title: "Float", detail: "", icon: Self.floatIcon, key: key))
        }
        if showsInMenuBar {
            rows.append("row=\(menuBarRun)\ntitle=Show in the menu bar\nicon=\(Self.menuBarIcon)\nhides=\(Self.clear)\nvalue=\(config.arrangement.menuBar.contains(spot))\n")
        }
        return (actions + rows).joined(separator: "\n")
    }

    private func fieldRow(_ field: CommandOffer, _ value: String?) -> String {
        let run = "row=\(Self.settingPrefix)\(spot):\(field.id)\ntitle=\(field.title)\n"
        let hides = value == nil ? "hides=\(Self.clear)\n" : ""
        return "\(run)detail=\(value ?? "Not set")\nicon=\(Self.valueIcon)\n\(hides)"
    }

    private func keyRows(_ keys: [GlobalKey]) -> [String] {
        let isSole = offers.count == 1
        return offers.map { offer in
            let key = keys.first { $0.spot == spot && $0.act == .command(offer.id) }
            let detail = !isSole ? "" : key == nil ? "detail=Press ⏎ to set\n" : "detail=Press ⌘↓ to select\nfocus=Press ⏎ to change\n"
            let title = isSole ? "\(offer.title) \(Self.soleTitle)" : offer.title
            return keyRow(run: Self.keyRun(spot: spot, command: offer.id), title: title, detail: detail, icon: Self.keyIcon, key: key)
        }
    }

    private func keyRow(run: String, title: String, detail: String, icon: String, key: GlobalKey?) -> String {
        let hides = key == nil ? "hides=\(Self.clear)\n" : ""
        return "row=\(run)\ntitle=\(title)\n\(detail)icon=\(icon)\n\(hides)type=hotkey\nshake=true\nshortcut=\(key?.trigger.text ?? Self.unset)\n"
    }

    private func command(of run: String) -> String? {
        guard run.hasPrefix("\(Self.keyPrefix)\(spot):") else { return nil }
        let command = String(run.dropFirst(Self.keyPrefix.count + spot.count + 1))
        return offers.contains { $0.id == command } ? command : nil
    }
}
