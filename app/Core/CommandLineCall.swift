import Foundation

/// What the `openspot` command was asked to do: `openspot <noun> <verb>`. No arguments start the app.
public enum CommandLineCall: Equatable, Sendable {
    case check(String?)
    case catalog
    case colorPick
    case translate(from: String?, to: String?)
    case translateLanguages
    case help
    case unknown(String)

    public static let usage = """
    openspot check [folder]                      Reports the faults of a plugins folder.
    openspot catalog                             Prints each part that a script can print.
    openspot color pick                          Prints the colour the person picks.
    openspot translate [--from code] [--to code] Translates the text on stdin.
    openspot translate languages                 Prints the languages it knows.

    """

    /// Returns nil when these arguments start the app, such as none or the flags that the system passes.
    public init?(arguments: [String]) {
        guard let noun = arguments.first else { return nil }
        if noun == "--help" || noun == "help" {
            self = .help
            return
        }
        guard !noun.hasPrefix("-") else { return nil }
        let rest = Array(arguments.dropFirst())
        switch (noun, rest.first) {
        case ("check", _) where rest.count <= 1: self = .check(rest.first)
        case ("catalog", nil): self = .catalog
        case ("color", "pick") where rest.count == 1: self = .colorPick
        case ("translate", "languages") where rest.count == 1: self = .translateLanguages
        case ("translate", _):
            guard let options = Self.options(rest) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = .translate(from: options["--from"].flatMap { $0 == "auto" ? nil : $0 }, to: options["--to"])
        default: self = .unknown(arguments.joined(separator: " "))
        }
    }

    /// Reads `--from` and `--to`, each with a value. Returns nil for anything else.
    private static func options(_ words: [String]) -> [String: String]? {
        guard words.count.isMultiple(of: 2) else { return nil }
        var options: [String: String] = [:]
        for index in stride(from: 0, to: words.count, by: 2) {
            guard words[index] == "--from" || words[index] == "--to" else { return nil }
            options[words[index]] = words[index + 1]
        }
        return options
    }
}
