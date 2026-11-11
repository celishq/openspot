import Foundation

/// The Settings spot, which ships with the app. It answers the calls a sheet script answers, in Swift.
public struct SettingsSpot: Equatable, Sendable {
    private static let panelKey = "panel_key"
    private static let fixKey = "fix_key"
    private static let keyPrefix = "key:"
    private static let floatPrefix = "float:"
    private static let settingPrefix = "setting:"
    private static let menuBarPrefix = "menubar:"
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
        return first == "read" || first == Self.clear || Self.takesShake(first)
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
        case "open" where arguments.dropFirst().first?.hasPrefix(Self.menuBarPrefix) == true:
            let id = String(arguments[1].dropFirst(Self.menuBarPrefix.count))
            try file.showInMenuBar(id, !file.read().arrangement.menuBar.contains(id))
            return ""
        case Self.panelKey, Self.fixKey:
            try file.set(arguments[0], to: try shortcut(from: arguments).text)
            return ""
        case Self.clear:
            if let found = Self.setting(of: arguments.dropFirst().first) {
                try file.set(setting: found.key, of: found.spot, to: nil)
            } else if let run = arguments.dropFirst().first, let found = target(of: run) {
                try assign(nil, to: found)
            }
            return ""
        case let run? where target(of: run) != nil:
            guard let trigger = arguments.dropFirst().first.flatMap(Trigger.init(text:)) else {
                throw PluginError.failed(1, "Openspot cannot use this key.")
            }
            try assign(trigger, to: target(of: run)!)
            return ""
        default:
            throw PluginError.failed(1, "Settings cannot do that.")
        }
    }

    private var sheet: String {
        let config = file.read()
        let panel = "row=\(Self.panelKey)\ntitle=Open Openspot\nicon=keyboard\nhides=\(Self.clear)\nshortcut=\((config.panelKey ?? .standard).text)\n"
        let fix = "row=\(Self.fixKey)\ntitle=Open a fix\nicon=wrench.and.screwdriver\nhides=\(Self.clear)\nshortcut=\((config.fixKey ?? .fix).text)\n"
        let scan = try? PluginFolder(url: folder, core: core, enabled: config.arrangement.enabled).scan()
        let scripts = (scan?.scripts ?? []).filter { only == nil || $0.id == only }
        let floats = only != nil ? [] : scripts.filter(\.offersFloat).map { script in
            keyRow(of: script, act: .float, title: "Float", icon: Self.picture(of: script), keys: config.keys)
        }
        let menuBar = only != nil ? [] : scripts.filter(\.canShowInMenuBar).map { script in
            TextBlock(fields: [
                .init(key: "row", value: "\(Self.menuBarPrefix)\(script.id)"),
                .init(key: "title", value: "Show in the menu bar"),
                .init(key: "detail", value: script.name),
                .init(key: "parent", value: script.name),
                .init(key: "icon", value: Self.picture(of: script)),
                .init(key: "hides", value: Self.clear),
                .init(key: "on", value: String(config.arrangement.menuBar.contains(script.id)))
            ]).text
        }
        let rows = floats + scripts.flatMap { script in
            script.offers.map { offer in
                keyRow(of: script, act: .command(offer.id), title: offer.title, icon: offer.icon ?? Self.picture(of: script), keys: config.keys)
            }
        }
        let named = scripts.flatMap { script in script.settings.map { (spot: script.id, offer: $0) } }
        let kept = config.settings.filter { setting in !named.contains { $0.spot == setting.spot && $0.offer.id == setting.key } }
            .compactMap { setting in CommandOffer(setting: setting.key).map { (spot: setting.spot, offer: $0) } }
        let values = only != nil ? [] : (named + kept).map { spot, offer -> String in
            let script = scripts.first { $0.id == spot }
            let value = config.setting(offer.id, of: spot)
            let name = script?.name ?? spot
            let icon = offer.icon ?? script.map(Self.picture(of:)) ?? "gearshape"
            return TextBlock(fields: [
                .init(key: "row", value: "\(Self.settingPrefix)\(spot):\(offer.id)"),
                .init(key: "title", value: offer.title),
                .init(key: "detail", value: "\(name) · \(value ?? "Not set")"),
                .init(key: "parent", value: name),
                .init(key: "icon", value: icon)
            ] + (value == nil ? [.init(key: "hides", value: Self.clear)] : [])).text
        }
        let login = self.login.map { [$0.row.text] } ?? []
        let link = self.link.map { [$0.row.text] } ?? []
        let app = only == nil ? [panel, fix] + login + link : []
        let actions = ["recents=false\n", "button=open\ntitle=Change\nclose=false\n", "button=\(Self.clear)\ntitle=Remove\nshortcut=cmd+backspace\n"]
        return (actions + app + menuBar + rows + values).joined(separator: "\n")
    }

    private func shortcut(from arguments: [String]) throws -> Shortcut {
        guard let shortcut = arguments.dropFirst().first.flatMap(Shortcut.init(text:)) else {
            throw PluginError.failed(1, "Openspot cannot use this key.")
        }
        return shortcut
    }

    /// The row that gives a command, or the float of a spot, its key, with Record until it has one. The full list names the
    /// spot of each row.
    private func keyRow(of script: Spot, act: GlobalKey.Act, title: String, icon: String, keys: [GlobalKey]) -> String {
        let key = keys.first { $0.spot == script.id && $0.act == act }
        let run = switch act {
        case .float: "\(Self.floatPrefix)\(script.id)"
        case .command(let command): "\(Self.keyPrefix)\(script.id):\(command)"
        }
        let hides = key == nil ? "hides=\(Self.clear)\n" : ""
        let detail = only == nil ? "detail=\(script.name)\nparent=\(script.name)\n" : ""
        return "row=\(run)\ntitle=\(title)\n\(detail)icon=\(icon)\n\(hides)shortcut=\(key?.trigger.text ?? "Record")\n"
    }

    /// The picture that its header names, or else its symbol.
    private static func picture(of script: Spot) -> String {
        script.image ?? script.file ?? script.glyph ?? script.symbol
    }

    /// The action of a spot that Enter on its setting row runs: the one with the name of the setting, which closes the panel.
    public static func change(of run: String) -> (spot: String, action: CommandAction)? {
        guard let (spot, key) = setting(of: run) else { return nil }
        return (spot, CommandAction(id: key, title: "Change \(key)", scope: .command, after: .close))
    }

    /// The spot and the key of the setting that the run of a row names.
    private static func setting(of run: String?) -> (spot: String, key: String)? {
        guard let run, run.hasPrefix(Self.settingPrefix), let split = run.dropFirst(Self.settingPrefix.count).firstIndex(of: ":") else { return nil }
        return (String(run[run.index(run.startIndex, offsetBy: Self.settingPrefix.count)..<split]), String(run[run.index(after: split)...]))
    }

    /// Whether the row of this run gives a key to a command or a float, which a shake can be (W2).
    public static func takesShake(_ run: String) -> Bool {
        run.hasPrefix(keyPrefix) || run.hasPrefix(floatPrefix)
    }

    /// The spot and the act that the run of a row gives a key to.
    private func target(of run: String) -> (spot: String, act: GlobalKey.Act)? {
        if run.hasPrefix(Self.floatPrefix) { return (String(run.dropFirst(Self.floatPrefix.count)), .float) }
        guard run.hasPrefix(Self.keyPrefix), let split = run.lastIndex(of: ":") else { return nil }
        return (String(run[run.index(run.startIndex, offsetBy: Self.keyPrefix.count)..<split]), .command(String(run[run.index(after: split)...])))
    }

    /// Gives a command, or the float of a spot, this key or the shake in the file, or takes its key away, and keeps the place
    /// of each other key. One key at most holds the shake, so a new shake takes it from the one before (W2).
    private func assign(_ trigger: Trigger?, to target: (spot: String, act: GlobalKey.Act)) throws {
        var keys = file.read().keys
        if trigger == .shake { keys.removeAll { $0.trigger == .shake && ($0.spot != target.spot || $0.act != target.act) } }
        let place = keys.firstIndex { $0.spot == target.spot && $0.act == target.act }
        let key = trigger.map { GlobalKey(spot: target.spot, act: target.act, trigger: $0) }
        switch (place, key) {
        case (let place?, let key?): keys[place] = key
        case (let place?, nil): keys.remove(at: place)
        case (nil, let key?): keys.append(key)
        case (nil, nil): break
        }
        try file.write(keys: keys)
    }
}
