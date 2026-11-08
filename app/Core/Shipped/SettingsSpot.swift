import Foundation

/// The Settings spot, which ships with the app. It answers the calls a sheet script answers, in Swift.
public struct SettingsSpot: Equatable, Sendable {
    private static let panelKey = "panel_key"
    private static let fixKey = "fix_key"
    private static let keyPrefix = "key:"
    private static let clear = "clear"

    public let file: ConfigFile
    /// The plugins folder and the core folder, whose headers list the commands that can take a key.
    public let folder: URL
    public let core: URL?
    public let login: LoginItem?
    public let link: CommandLink?

    public init(file: ConfigFile, folder: URL, core: URL? = nil, login: LoginItem? = nil, link: CommandLink? = nil) {
        self.file = file
        self.folder = folder
        self.core = core
        self.login = login
        self.link = link
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
        case Self.panelKey, Self.fixKey:
            try file.set(arguments[0], to: try shortcut(from: arguments).text)
            return ""
        case Self.clear:
            if let run = arguments.dropFirst().first, let found = target(of: run) { try assign(nil, to: found) }
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
        let panel = "row=Open Openspot\nrun=\(Self.panelKey)\nsymbol=keyboard\nhides=\(Self.clear)\nshortcut=\((config.panelKey ?? .standard).text)\n"
        let fix = "row=Open a fix\nrun=\(Self.fixKey)\nsymbol=wrench.and.screwdriver\nhides=\(Self.clear)\nshortcut=\((config.fixKey ?? .fix).text)\n"
        let scripts = (try? PluginFolder(url: folder, core: core, enabled: config.arrangement.enabled).scan())?.scripts ?? []
        let rows = scripts.flatMap { script in
            script.offers.map { offer -> String in
                let key = config.keys.first { $0.spot == script.id && $0.command == offer.id }
                let hides = key == nil ? "hides=\(Self.clear)\n" : ""
                return "row=\(offer.title)\ndetail=\(script.name)\nrun=\(Self.keyPrefix)\(script.id):\(offer.id)\nsymbol=\(offer.symbol ?? script.symbol)\n\(hides)shortcut=\(key?.shortcut.text ?? "Record")\n"
            }
        }
        let login = self.login.map { [$0.row.text] } ?? []
        let link = self.link.map { [$0.row.text] } ?? []
        return (["recents=false\n", "action=open\ntitle=Change\nclose=false\n", "action=\(Self.clear)\ntitle=Remove key\n", panel, fix] + login + link + rows).joined(separator: "\n")
    }

    private func shortcut(from arguments: [String]) throws -> Shortcut {
        guard let shortcut = arguments.dropFirst().first.flatMap(Shortcut.init(text:)) else {
            throw PluginError.failed(1, "Openspot cannot use this key.")
        }
        return shortcut
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
