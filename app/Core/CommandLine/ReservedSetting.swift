import Foundation

/// A setting whose key Openspot keeps for the person, not for the spot: where a spot shows (`enabled`, `menubar`, `float`
/// and `key.<command>`), and on the spot `openspot`, the app (`login`, `link`, `careful`, `panel-key` and `fix-key`).
/// `openspot setting set` of such a key runs the call that does the work.
enum ReservedSetting {
    /// The spot that stands for the app.
    static let app = "openspot"
    private static let commandKey = "key."
    private static let spotKeys: Set<String> = ["enabled", "menubar", "float"]
    private static let appKeys: Set<String> = ["login", "link", "careful", "panel-key", "fix-key"]

    /// Whether a spot cannot name this key as a value of its own.
    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || key.hasPrefix(commandKey)
    }

    /// The words of the call that sets the key of the spot to the value, or a refusal of a value that does not fit, or nil
    /// for a key that is the spot's own.
    static func call(spot: String, key: String, value: String?) -> Result<[String], Refusal>? {
        let flag = value.flatMap { ["true": "on", "false": "off"][$0] }
        func on(_ words: (String) -> [String]) -> Result<[String], Refusal> {
            flag.map { .success(words($0)) } ?? .failure(Refusal("`\(key)` takes `true` or `false`, such as `openspot setting set --spot \(spot) \(key) true`."))
        }
        if spot == app, appKeys.contains(key) {
            switch key {
            case "panel-key", "fix-key":
                guard let value else { return .failure(Refusal("`\(key)` needs a key, such as `openspot setting set --spot openspot \(key) ctrl+space`.")) }
                return .success(["key", "set", key == "panel-key" ? "--panel" : "--fix", value])
            default: return on { ["app", key, $0] }
            }
        }
        switch key {
        case "enabled": return on { ["spot", $0, spot] }
        case "menubar": return on { ["menubar", $0, spot] }
        case "float": return .success(["key", "set", spot, "--float"] + (value.map { [$0] } ?? []))
        case let key where key.hasPrefix(commandKey):
            return .success(["key", "set", spot, String(key.dropFirst(commandKey.count))] + (value.map { [$0] } ?? []))
        default: return nil
        }
    }

    /// Why a reserved setting cannot be set as it was asked.
    struct Refusal: Error, Equatable {
        let line: String

        init(_ line: String) {
            self.line = line
        }
    }

    /// The new form of a call that this setting took the place of, or nil for any other call.
    static func replacement(of arguments: [String]) -> String? {
        form(of: arguments)?.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func form(of arguments: [String]) -> String? {
        let words = arguments + ["", "", ""]
        switch (words[0], words[1]) {
        case ("key", "set"):
            switch words[2] {
            case "--panel": return "openspot setting set --spot openspot panel-key \(words[3])"
            case "--fix": return "openspot setting set --spot openspot fix-key \(words[3])"
            default: return words[3] == "--float" ? "openspot setting set --spot \(words[2]) float \(words[4])" : "openspot setting set --spot \(words[2]) key.\(words[3]) \(words[4])"
            }
        case ("menubar", "on"), ("menubar", "off"): return "openspot setting set --spot \(words[2]) menubar \(words[1] == "on")"
        case ("spot", "on"), ("spot", "off"): return "openspot setting set --spot \(words[2]) enabled \(words[1] == "on")"
        case ("app", "login"), ("app", "link"), ("app", "careful"): return "openspot setting set --spot openspot \(words[1]) \(words[2] == "on")"
        default: return nil
        }
    }

    /// The call that `openspot setting set` of a reserved key runs, or its refusal, or nil for any other call. `spot` is
    /// the spot of the caller, which `--spot` replaces.
    static func call(of arguments: [String], spot: String?) -> Result<[String], Refusal>? {
        guard arguments.count >= 3, arguments[0] == "setting", arguments[1] == "set" else { return nil }
        var words = Array(arguments.dropFirst(2))
        var spot = spot
        if words.first == "--spot", words.count > 1 {
            spot = words[1]
            words.removeFirst(2)
        }
        guard let spot, let key = words.first, words.count <= 2 else { return nil }
        return call(spot: spot, key: key, value: words.dropFirst().first)
    }

    /// The words of the call that a setting of a reserved key runs, or the words as they are.
    static func words(of arguments: [String], spot: String?) -> [String] {
        guard case .success(let words)? = call(of: arguments, spot: spot) else { return arguments }
        return words
    }
}
