import Foundation

public struct RaycastScript: Equatable, Sendable {
    public enum Mode: String, Sendable {
        case silent
        case compact
        case fullOutput
        case inline
    }

    public enum Skip: Error, Equatable, Sendable {
        case notScript
        case template
        case windows
        case schema(String)
        case mode(String)
        case argument(Int)

        public var reason: String {
            switch self {
            case .notScript: "not a script command"
            case .template: "a template: fill it in, then import it"
            case .windows: "made for Windows"
            case .schema(let version): "schema version \(version), and Openspot reads version 1"
            case .mode(let mode): "mode \(mode), which Raycast does not have"
            case .argument(let number): "argument\(number) is not valid JSON"
            }
        }
    }

    public let title: String
    public let mode: Mode
    public let icon: String?
    public let description: String?
    public let package: String?
    public let arguments: [RaycastArgument]
    public let confirms: Bool
    public let refreshSeconds: Int?
    public let directory: String?

    public static let headerLimit = 64 * 1024
    static let shortestRefresh = 10

    public init(text: String, name: String) throws(Skip) {
        guard !name.contains(".template.") else { throw .template }
        let keys = Self.keys(of: text)
        guard text.hasPrefix("#!"), let title = keys["title"], let given = keys["mode"] else { throw .notScript }
        if let version = keys["schemaVersion"], version != "1" { throw .schema(version) }
        if keys["platform"]?.lowercased() == "windows" { throw .windows }
        guard let mode = Mode(rawValue: given) else { throw .mode(given) }
        var arguments: [RaycastArgument] = []
        for number in 1...3 {
            guard let json = keys["argument\(number)"] else { break }
            guard let argument = RaycastArgument(json: json) else { throw .argument(number) }
            arguments.append(argument)
        }
        let refresh = keys["refreshTime"].flatMap(Self.seconds)
        self.title = title
        self.mode = mode == .inline && (refresh == nil || !arguments.isEmpty) ? .compact : mode
        icon = keys["icon"]
        description = keys["description"].map(Self.plain)
        package = keys["packageName"] ?? keys["packagename"]
        self.arguments = arguments
        confirms = keys["needsConfirmation"] == "true"
        refreshSeconds = self.mode == .inline ? refresh.map { max($0, Self.shortestRefresh) } : nil
        directory = keys["currentDirectoryPath"]
    }

    static func keys(of text: String) -> [String: String] {
        var keys: [String: String] = [:]
        for line in text.utf8.prefix(headerLimit).split(separator: UInt8(ascii: "\n")) {
            guard let line = String(line), line.contains("@raycast."), let (key, value) = pair(of: line), keys[key] == nil else { continue }
            keys[key] = value
        }
        return keys
    }

    static func pair(of line: String) -> (String, String)? {
        var rest = line.drop { $0 == " " || $0 == "\t" }
        guard let mark = ["#", "//", "--"].first(where: { rest.hasPrefix($0) }) else { return nil }
        rest = rest.dropFirst(mark.count).drop { $0 == " " || $0 == "\t" }
        guard rest.hasPrefix("@raycast.") else { return nil }
        rest = rest.dropFirst("@raycast.".count)
        let key = rest.prefix { $0.isLetter || $0.isNumber }
        let value = rest.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty, rest.dropFirst(key.count).first?.isWhitespace == true else { return nil }
        return (String(key), value)
    }

    static func seconds(_ text: String) -> Int? {
        guard let found = text.wholeMatch(of: /\s*(\d+)\s*([smhd])\s*/), let count = Int(found.1) else { return nil }
        let unit = ["s": 1, "m": 60, "h": 3600, "d": 86400][String(found.2)] ?? 1
        return count * unit
    }

    static func plain(_ text: String) -> String {
        text.replacing(/\[([^\]]*)\]\([^)]*\)/) { String($0.1) }
    }
}
