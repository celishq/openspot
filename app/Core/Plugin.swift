import Foundation

/// A folder with a manifest.toml and the executables its commands run.
public struct Plugin: Equatable, Sendable {
    public let name: String
    public let api: Int
    public let url: URL
    public let commands: [PluginCommand]

    public init(name: String, api: Int, url: URL, commands: [PluginCommand]) {
        self.name = name
        self.api = api
        self.url = url
        self.commands = commands
    }

    /// Reads a plugin from its manifest text. Throws a fault that names what is wrong.
    public init(manifest text: String, url: URL) throws {
        let document = try TomlDocument(text: text)
        guard case .string(let name)? = document.values["name"] else { throw PluginError.manifest("needs a name") }
        guard case .integer(let api)? = document.values["api"] else { throw PluginError.manifest("needs an api") }
        guard api == OpenspotVersion.api else { throw PluginError.manifest("needs api \(api)") }
        let commands = try (document.arrays["commands"] ?? []).map { try Self.command($0, plugin: url) }
        self.init(name: name, api: api, url: url, commands: commands)
    }

    private static func command(_ table: [String: TomlDocument.Value], plugin: URL) throws -> PluginCommand {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let name = text("name") else { throw PluginError.manifest("a command needs a name") }
        guard let exec = text("exec") else { throw PluginError.manifest("\(name) needs an exec") }
        let url = plugin.appendingPathComponent(exec)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PluginError.manifest("\(name) needs a file named \(exec)")
        }
        let typeName = text("type") ?? SpotKind.launch.rawValue
        guard let kind = SpotKind(rawValue: typeName) else {
            throw PluginError.manifest("\(name) has an unknown type: \(typeName)")
        }
        let sizeName = text("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else {
            throw PluginError.manifest("\(name) has an unknown size: \(sizeName)")
        }
        var key: CommandKey?
        if let keyName = text("key") {
            guard let parsed = CommandKey(name: keyName) else {
                throw PluginError.manifest("\(name) has an unknown key: \(keyName)")
            }
            key = parsed
        }
        let pickName = text("pick") ?? ItemPick.close.rawValue
        guard let pick = ItemPick(rawValue: pickName) else {
            throw PluginError.manifest("\(name) has an unknown pick: \(pickName)")
        }
        let searchName = text("search") ?? ItemSearch.local.rawValue
        guard let search = ItemSearch(rawValue: searchName) else {
            throw PluginError.manifest("\(name) has an unknown search: \(searchName)")
        }
        let isGlobal = table["global"] == .boolean(true)
        guard !isGlobal || search == .local else {
            throw PluginError.manifest("\(name) cannot join the main search, because it searches live")
        }
        return PluginCommand(
            id: "\(plugin.lastPathComponent)/\(name)",
            name: name,
            url: url,
            kind: kind,
            size: size,
            symbol: text("symbol") ?? "app",
            subtitle: text("subtitle"),
            key: key,
            hasState: table["state"] == .boolean(true),
            pick: pick,
            isGlobal: isGlobal,
            search: search,
            keepsRecent: table["recents"] != .boolean(false)
        )
    }
}
