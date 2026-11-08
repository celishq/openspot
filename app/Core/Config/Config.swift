import Foundation

/// What the config file asks for. A value that it cannot use is a fault, and the others still count.
public struct Config: Equatable, Sendable {
    /// The key that opens the panel. Nil when the file asks for one that it cannot use.
    public private(set) var panelKey: Shortcut? = .standard
    /// The key that opens the link of a failure toast. Nil when the file asks for one that it cannot use.
    public private(set) var fixKey: Shortcut? = .fix
    public private(set) var faults: [String] = []
    public private(set) var arrangement = SpotArrangement()
    /// The keys that the person assigned to commands of scripts.
    public private(set) var keys: [GlobalKey] = []

    public init(text: String) {
        let document: TomlDocument
        do {
            document = try TomlDocument(text: text)
        } catch {
            panelKey = nil
            faults = ["config.toml: \((error as? PluginError)?.reason ?? String(describing: error))"]
            return
        }
        for key in (Array(document.values.keys) + Array(document.arrays.keys)).sorted() where !["panel_key", "fix_key", "spots", "keys"].contains(key) {
            faults.append("config.toml: \(key) is not a setting.")
        }
        arrangement = SpotArrangement(choices: (document.arrays["spots"] ?? []).compactMap { choice(of: $0) })
        keys = (document.arrays["keys"] ?? []).compactMap { key(of: $0) }
        panelKey = shortcut(document.values["panel_key"], named: "panel_key", or: .standard)
        fixKey = shortcut(document.values["fix_key"], named: "fix_key", or: .fix)
    }

    /// Reads one key setting. A value that it cannot use is a fault, and gives no key.
    private mutating func shortcut(_ value: TomlDocument.Value?, named name: String, or standard: Shortcut) -> Shortcut? {
        guard let value else { return standard }
        if case .string(let text) = value, let shortcut = Shortcut(text: text) { return shortcut }
        let word = if case .string(let text) = value { text } else { "this value" }
        faults.append("config.toml: \(name) cannot use \(word). Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.")
        return nil
    }

    /// Reads one `[[keys]]` table. A table that it cannot use is a fault.
    private mutating func key(of table: [String: TomlDocument.Value]) -> GlobalKey? {
        guard case .string(let spot)? = table["spot"], case .string(let command)? = table["command"], case .string(let text)? = table["key"] else {
            faults.append("config.toml: a key needs a spot, a command and a key.")
            return nil
        }
        guard let shortcut = Shortcut(text: text) else {
            faults.append("config.toml: \(spot) \(command) cannot use \(text).")
            return nil
        }
        return GlobalKey(spot: spot, command: command, shortcut: shortcut)
    }

    /// Reads one `[[spots]]` table. A table with no id is a fault, and any other bad value leaves that value out.
    private mutating func choice(of table: [String: TomlDocument.Value]) -> SpotArrangement.Choice? {
        guard case .string(let id)? = table["id"] else {
            faults.append("config.toml: a spot needs an id.")
            return nil
        }
        var choice = SpotArrangement.Choice(id: id)
        if case .string(let name)? = table["size"] {
            choice.size = SpotSize(name: name)
            if choice.size == nil { faults.append("config.toml: \(id) cannot use the size \(name).") }
        }
        if case .boolean(let isOnGrid)? = table["grid"] { choice.isOnGrid = isOnGrid }
        if case .boolean(let isEnabled)? = table["enabled"] { choice.isEnabled = isEnabled }
        if case .boolean(let isGlobal)? = table["global"] { choice.isGlobal = isGlobal }
        for key in table.keys.sorted() where !["id", "size", "grid", "enabled", "global"].contains(key) {
            faults.append("config.toml: \(key) is not a setting of a spot.")
        }
        return choice
    }
}
