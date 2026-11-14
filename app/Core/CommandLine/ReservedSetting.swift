import Foundation

enum ReservedSetting {
    static let appSpot = "openspot"
    private static let commandKey = "key."
    static let icon = "icon"
    private static let spotKeys: Set<String> = ["enabled", "menubar", "float", icon]
    private static let appKeys: Set<String> = ["login", "link", "careful", "panel-key", "fix-key"]

    static func isReserved(_ key: String) -> Bool {
        spotKeys.contains(key) || appKeys.contains(key) || key.hasPrefix(commandKey)
    }

    static func call(spot: String, key: String, value: String?) -> Result<[String], Refusal>? {
        let flag = value.flatMap { ["true": "on", "false": "off"][$0] }
        func on(_ words: (String) -> [String]) -> Result<[String], Refusal> {
            flag.map { .success(words($0)) } ?? .failure(Refusal("`\(key)` takes `true` or `false`, such as `openspot setting set --spot \(spot) \(key) true`."))
        }
        if spot == appSpot, appKeys.contains(key) {
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

    struct Refusal: Error, Equatable {
        let line: String

        init(_ line: String) {
            self.line = line
        }
    }

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

    static func words(of arguments: [String], spot: String?) -> [String] {
        guard case .success(let words)? = call(of: arguments, spot: spot) else { return arguments }
        return words
    }
}
