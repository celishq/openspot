import Foundation

/// A folder with a manifest.toml and the executables its commands run.
public struct Plugin: Equatable, Sendable {
    public let name: String
    public let api: Int
    public let url: URL
    public let commands: [PluginCommand]
    public let metrics: [PluginMetric]

    public init(name: String, api: Int, url: URL, commands: [PluginCommand], metrics: [PluginMetric] = []) {
        self.name = name
        self.api = api
        self.url = url
        self.commands = commands
        self.metrics = metrics
    }

    /// Reads a plugin from its manifest text. Throws a fault that names what is wrong.
    public init(manifest text: String, url: URL) throws {
        let document = try TomlDocument(text: text)
        guard case .string(let name)? = document.values["name"] else { throw PluginError.manifest("needs a name") }
        guard case .integer(let api)? = document.values["api"] else { throw PluginError.manifest("needs an api") }
        guard api == OpenspotVersion.api else { throw PluginError.manifest("needs api \(api)") }
        let actions = try (document.arrays["actions"] ?? []).map(Self.action)
        let commands = try (document.arrays["commands"] ?? []).map { table in
            try Self.command(table, plugin: url, actions: actions)
        }
        if let lost = actions.first(where: { action in !commands.contains { $0.name == action.command } }) {
            throw PluginError.manifest("An action names no command called \(lost.command)")
        }
        let widgets = try (document.arrays["widgets"] ?? []).map { try Self.widget($0, plugin: url) }
        let metrics = try (document.arrays["metrics"] ?? []).map { try Self.metric($0, plugin: url) }
        self.init(name: name, api: api, url: url, commands: commands + widgets, metrics: metrics)
    }

    private static func metric(_ table: [String: TomlDocument.Value], plugin: URL) throws -> PluginMetric {
        guard case .string(let name)? = table["name"] else { throw PluginError.manifest("a metric needs a name") }
        guard case .string(let exec)? = table["exec"] else { throw PluginError.manifest("\(name) needs an exec") }
        let url = plugin.appendingPathComponent(exec)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PluginError.manifest("\(name) needs a file named \(exec)")
        }
        guard case .string(let kindName)? = table["kind"], let kind = MetricKind(rawValue: kindName) else {
            throw PluginError.manifest("\(name) needs a kind: value, gauge, trend, rows or status")
        }
        var refresh = PluginMetric.standardRefresh
        if let value = table["refresh"] {
            guard case .integer(let seconds) = value, seconds > 0 else {
                throw PluginError.manifest("\(name) needs a number of seconds as its refresh")
            }
            refresh = TimeInterval(seconds)
        }
        return PluginMetric(id: "\(plugin.lastPathComponent)/\(name)", name: name, url: url, kind: kind, refresh: refresh)
    }

    private static func widget(_ table: [String: TomlDocument.Value], plugin: URL) throws -> PluginCommand {
        guard case .string(let name)? = table["name"] else { throw PluginError.manifest("a widget needs a name") }
        guard case .string(let layoutName)? = table["layout"] else { throw PluginError.manifest("\(name) needs a layout") }
        guard let layout = WidgetLayout(name: layoutName) else {
            throw PluginError.manifest("\(name) has an unknown layout: \(layoutName). Use hero, quad, pair or row")
        }
        guard case .strings(let places)? = table["places"], places.count == layout.slots.count else {
            throw PluginError.manifest("\(name) needs \(layout.slots.count) places for the \(layoutName) layout")
        }
        var key: CommandKey?
        if case .string(let keyName)? = table["key"] {
            guard let parsed = CommandKey(name: keyName) else {
                throw PluginError.manifest("\(name) has an unknown key: \(keyName)")
            }
            key = parsed
        }
        var opens: String?
        if case .string(let target)? = table["opens"] { opens = target }
        return PluginCommand(
            id: "\(plugin.lastPathComponent)/\(name)",
            name: name,
            url: plugin,
            kind: .widget,
            size: layout.size,
            key: key,
            layout: layout,
            places: places,
            opens: opens
        )
    }

    private static func action(_ table: [String: TomlDocument.Value]) throws -> (command: String, action: CommandAction) {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let command = text("command"), let id = text("id"), let title = text("title") else {
            throw PluginError.manifest("An action needs a command, an id and a title")
        }
        var key: ActionKey?
        if let keyName = text("key") {
            guard let parsed = ActionKey(text: keyName) else {
                throw PluginError.manifest("\(title) has an unknown key: \(keyName)")
            }
            key = parsed
        }
        guard let scope = CommandAction.Scope(rawValue: text("scope") ?? CommandAction.Scope.item.rawValue) else {
            throw PluginError.manifest("\(title) has an unknown scope")
        }
        guard let after = CommandAction.After(rawValue: text("after") ?? CommandAction.After.stay.rawValue) else {
            throw PluginError.manifest("\(title) has an unknown after")
        }
        return (command, CommandAction(
            id: id,
            title: title,
            key: key,
            scope: scope,
            after: after,
            isForm: table["form"] == .boolean(true),
            confirm: text("confirm")
        ))
    }

    private static func command(
        _ table: [String: TomlDocument.Value],
        plugin: URL,
        actions: [(command: String, action: CommandAction)]
    ) throws -> PluginCommand {
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
        guard let kind = SpotKind(rawValue: typeName), kind != .widget else {
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
        var rank = PluginCommand.lastRank
        if let value = table["rank"] {
            guard case .integer(let number) = value else { throw PluginError.manifest("\(name) needs a number as its rank") }
            rank = number
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
            rank: rank,
            search: search,
            keepsRecent: table["recents"] != .boolean(false),
            primary: text("primary"),
            actions: actions.filter { $0.command == name }.map(\.action)
        )
    }
}
