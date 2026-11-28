import Foundation

/// The command that starts an agent, as the person types it in a terminal, such as `claude-personal`.
struct Command {
    let text: String

    /// The folder that an alias of the command sets in a variable, such as `CLAUDE_CONFIG_DIR=~/.claude-personal`.
    func folder(alias: String, variable: String, home: String) -> String? {
        guard let start = alias.range(of: "\(variable)=") else { return nil }
        let value = alias[start.upperBound...].prefix { !$0.isWhitespace && $0 != "'" && $0 != "\"" }
        guard !value.isEmpty else { return nil }
        return value.hasPrefix("~") ? home + value.dropFirst() : String(value)
    }
}
