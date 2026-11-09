import Foundation

/// The Settings spot, which ships with the app. It answers the calls a sheet script answers, in Swift.
public struct SettingsSpot: Equatable, Sendable {
    private static let panelKey = "panel_key"
    private static let fixKey = "fix_key"
    private static let keyPrefix = "key:"
    private static let settingPrefix = "setting:"
    private static let clear = "clear"

    public let file: ConfigFile
    /// The plugins folder and the core folder, whose headers list the commands that can take a key.
    public let folder: URL
    public let core: URL?
    public let login: LoginItem?
    public let link: CommandLink?
    /// The ID of the one script whose commands it lists. Nil lists the keys of the app and of every script.
    public let only: String?

    public init(file: ConfigFile, folder: URL, core: URL? = nil, login: LoginItem? = nil, link: CommandLink? = nil, only: String? = nil) {
        self.file = file
        self.folder = folder
        self.core = core
        self.login = login
        self.link = link
        self.only = only
    }

    /// The keys of one script's commands alone.
    public func keys(of script: String) -> SettingsSpot {
        SettingsSpot(file: file, folder: folder, core: core, only: script)
    }

    /// Whether it answers this call: a read, or a change of a key. Any other call goes to the script.
    public func answers(_ arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        return first == "read" || first == Self.clear || first.hasPrefix(Self.keyPrefix)
    }

    /// Answers one call with the text a script would print. A change prints nothing, which asks for a new read.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case "open" where arguments.dropFirst().first == LoginItem.run:
            try login?.toggle()
            return ""
        case "open" where arguments.dropFirst().first == CommandLink.run:
            return try link?.toggle() ?? ""
        case "open" where setting(of: arguments.dropFirst().first) != nil:
            let spot = setting(of: arguments.dropFirst().first)!.spot
            return TextBlock(fields: [.init(key: "toast", value: "\(spot) keeps this value. Change it in \(spot), or press `⌘⌫` to remove it.")]).text
        case Self.panelKey, Self.fixKey:
            try file.set(arguments[0], to: try shortcut(from: arguments).text)
            return ""
        case Self.clear:
            if let found = setting(of: arguments.dropFirst().first) {
                try file.set(setting: found.key, of: found.spot, to: nil)
            } else if let run = arguments.dropFirst().first, let found = target(of: run) {
                try assign(nil, to: found)
            }
            return ""
        case let run? where target(of: run) != nil:
            try assign(try shortcut(from: arguments), to: target(of: run)!)
            return ""
        default:
            throw PluginError.failed(1, "Settings cannot do that.")
        }
    }

    private var sheet: String {
        let config = file.read()
        let panel = "row=\(Self.panelKey)\ntitle=Open Openspot\nicon=keyboard\nhides=\(Self.clear)\nshortcut=\((config.panelKey ?? .standard).text)\n"
        let fix = "row=\(Self.fixKey)\ntitle=Open a fix\nicon=wrench.and.screwdriver\nhides=\(Self.clear)\nshortcut=\((config.fixKey ?? .fix).text)\n"
        let scripts = ((try? PluginFolder(url: folder, core: core, enabled: config.arrangement.enabled).scan())?.scripts ?? []).filter { only == nil || $0.id == only }
        let rows = scripts.flatMap { script in
            script.offers.map { offer -> String in
                let key = config.keys.first { $0.spot == script.id && $0.command == offer.id }
                let hides = key == nil ? "hides=\(Self.clear)\n" : ""
                let detail = only == nil ? "detail=\(script.name)\nparent=\(script.name)\n" : ""
                return "row=\(Self.keyPrefix)\(script.id):\(offer.id)\ntitle=\(offer.title)\n\(detail)icon=\(offer.icon ?? script.image ?? script.file ?? script.glyph ?? script.symbol)\n\(hides)shortcut=\(key?.shortcut.text ?? "Record")\n"
            }
        }
        let values = only != nil ? [] : config.settings.map { setting -> String in
            let script = scripts.first { $0.id == setting.spot }
            let name = script?.name ?? setting.spot
            let icon = script.map { $0.image ?? $0.file ?? $0.glyph ?? $0.symbol } ?? "gearshape"
            return TextBlock(fields: [
                .init(key: "row", value: "\(Self.settingPrefix)\(setting.spot):\(setting.key)"),
                .init(key: "title", value: setting.key.prefix(1).uppercased() + setting.key.dropFirst()),
                .init(key: "detail", value: "\(name) · \(setting.value)"),
                .init(key: "parent", value: name),
                .init(key: "icon", value: icon)
            ]).text
        }
        let login = self.login.map { [$0.row.text] } ?? []
        let link = self.link.map { [$0.row.text] } ?? []
        let app = only == nil ? [panel, fix] + login + link : []
        let actions = ["recents=false\n", "button=open\ntitle=Change\nclose=false\n", "button=\(Self.clear)\ntitle=Remove\nshortcut=cmd+backspace\n"]
        return (actions + app + rows + values).joined(separator: "\n")
    }

    private func shortcut(from arguments: [String]) throws -> Shortcut {
        guard let shortcut = arguments.dropFirst().first.flatMap(Shortcut.init(text:)) else {
            throw PluginError.failed(1, "Openspot cannot use this key.")
        }
        return shortcut
    }

    /// The spot and the key of the setting that the run of a row names.
    private func setting(of run: String?) -> (spot: String, key: String)? {
        guard let run, run.hasPrefix(Self.settingPrefix), let split = run.dropFirst(Self.settingPrefix.count).firstIndex(of: ":") else { return nil }
        return (String(run[run.index(run.startIndex, offsetBy: Self.settingPrefix.count)..<split]), String(run[run.index(after: split)...]))
    }

    /// The spot and the command that the run of a row names.
    private func target(of run: String) -> (spot: String, command: String)? {
        guard run.hasPrefix(Self.keyPrefix), let split = run.lastIndex(of: ":") else { return nil }
        return (String(run[run.index(run.startIndex, offsetBy: Self.keyPrefix.count)..<split]), String(run[run.index(after: split)...]))
    }

    /// Gives a command this key in the file, or takes its key away, and keeps the place of each other key.
    private func assign(_ shortcut: Shortcut?, to target: (spot: String, command: String)) throws {
        var keys = file.read().keys
        let place = keys.firstIndex { $0.spot == target.spot && $0.command == target.command }
        let key = shortcut.map { GlobalKey(spot: target.spot, command: target.command, shortcut: $0) }
        switch (place, key) {
        case (let place?, let key?): keys[place] = key
        case (let place?, nil): keys.remove(at: place)
        case (nil, let key?): keys.append(key)
        case (nil, nil): break
        }
        try file.write(keys: keys)
    }
}
