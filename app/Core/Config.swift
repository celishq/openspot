import Foundation

/// What the config file asks for. A value that it cannot use is a fault, and the others still count.
public struct Config: Equatable, Sendable {
    /// The key that opens the panel. Nil when the file asks for one that it cannot use.
    public private(set) var panelKey: Shortcut? = .standard
    public private(set) var faults: [String] = []

    public init(text: String) {
        let document: TomlDocument
        do {
            document = try TomlDocument(text: text)
        } catch {
            panelKey = nil
            faults = ["config.toml: \((error as? PluginError)?.reason ?? String(describing: error))"]
            return
        }
        for key in (Array(document.values.keys) + Array(document.arrays.keys)).sorted() where key != "panel_key" {
            faults.append("config.toml: \(key) is not a setting.")
        }
        guard let value = document.values["panel_key"] else { return }
        if case .string(let text) = value, let shortcut = Shortcut(text: text) {
            panelKey = shortcut
        } else {
            panelKey = nil
            let word = if case .string(let text) = value { text } else { "this value" }
            faults.append("config.toml: panel_key cannot use \(word). Hold cmd, ctrl or option with a letter, a digit, space, return or tab.")
        }
    }
}
