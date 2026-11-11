import Foundation

/// What the config file asks for. A value that it cannot use is a fault, and the others still count.
public struct Config: Equatable, Sendable {
    /// The key that opens the panel. Nil when the file asks for one that it cannot use.
    public private(set) var panelKey: Shortcut? = .standard
    /// The key that opens the link of a failure toast. Nil when the file asks for one that it cannot use.
    public private(set) var fixKey: Shortcut? = .fix
    public private(set) var faults: [String] = []
    public private(set) var arrangement = SpotArrangement()
    /// The keys that the person assigned to commands of scripts, or to spots that they float.
    public private(set) var keys: [GlobalKey] = []
    /// The values that scripts keep for the person through `openspot setting` (K6).
    public private(set) var settings: [SpotSetting] = []

    public init(text: String) {
        let document: TomlDocument
        do {
            document = try TomlDocument(text: text)
        } catch {
            panelKey = nil
            faults = ["config.toml: \((error as? SpotError)?.reason ?? String(describing: error))"]
            return
        }
        for key in (Array(document.values.keys) + Array(document.arrays.keys)).sorted() where !["panel_key", "fix_key", "spots", "keys", "settings"].contains(key) {
            faults.append("config.toml: \(key) is not a setting.")
        }
        arrangement = SpotArrangement(choices: (document.arrays["spots"] ?? []).compactMap { choice(of: $0) })
        keys = (document.arrays["keys"] ?? []).compactMap { key(of: $0) }
        settings = (document.arrays["settings"] ?? []).compactMap { setting(of: $0) }
        panelKey = shortcut(document.values["panel_key"], named: "panel_key", or: .standard)
        fixKey = shortcut(document.values["fix_key"], named: "fix_key", or: .fix)
    }

    /// The value that a script keeps under this key for its spot.
    public func setting(_ key: String, of spot: String) -> String? {
        settings.first { $0.spot == spot && $0.key == key }?.value
    }

    /// Reads one `[[settings]]` table. A table that it cannot use is a fault.
    private mutating func setting(of table: [String: TomlDocument.Value]) -> SpotSetting? {
        guard case .string(let spot)? = table["spot"], case .string(let key)? = table["key"], case .string(let value)? = table["value"] else {
            faults.append("config.toml: a setting needs a spot, a key and a value.")
            return nil
        }
        return SpotSetting(spot: spot, key: key, value: value)
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
        guard case .string(let spot)? = table["spot"], case .string(let text)? = table["key"] else {
            faults.append("config.toml: a key needs a spot and a key.")
            return nil
        }
        let act: GlobalKey.Act = if case .string(let command)? = table["command"] { .command(command) } else { .float }
        guard let trigger = Trigger(text: text) else {
            let name = if case .command(let command) = act { "\(spot) \(command)" } else { spot }
            faults.append("config.toml: \(name) cannot use \(text).")
            return nil
        }
        return GlobalKey(spot: spot, act: act, trigger: trigger)
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
        if case .boolean(let isInMenuBar)? = table["tray"] { choice.isInMenuBar = isInMenuBar }
        if case .string(let text)? = table["key"] {
            choice.key = ActionKey(text: text)
            if choice.key == nil { faults.append("config.toml: \(id) cannot use the key \(text).") }
        }
        if case .string(let letter)? = table["letter"] {
            choice.letter = letter.isEmpty ? "" : CommandKey(name: letter)?.name
            if choice.letter == nil { faults.append("config.toml: \(id) cannot use the letter \(letter).") }
        }
        for key in table.keys.sorted() where !["id", "size", "grid", "enabled", "global", "tray", "letter", "key"].contains(key) {
            faults.append("config.toml: \(key) is not a setting of a spot.")
        }
        return choice
    }
}
