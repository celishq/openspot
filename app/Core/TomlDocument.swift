import Foundation

/// The part of TOML a plugin manifest uses: top-level pairs and arrays of tables, with strings, integers and booleans.
public struct TomlDocument: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case string(String)
        case integer(Int)
        case boolean(Bool)
    }

    public private(set) var values: [String: Value] = [:]
    public private(set) var arrays: [String: [[String: Value]]] = [:]

    public init(text: String) throws {
        var array: String?
        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let fault = { (reason: String) in PluginError.manifest("line \(index + 1): \(reason)") }
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") {
                guard line.hasPrefix("[["), let end = line.range(of: "]]") else {
                    throw fault("only arrays of tables are allowed, as in [[commands]]")
                }
                let name = String(line[line.index(line.startIndex, offsetBy: 2)..<end.lowerBound])
                arrays[name, default: []].append([:])
                array = name
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { throw fault("expected a key and a value") }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains(" ") else { throw fault("expected a key and a value") }
            guard let value = Self.value(line[line.index(after: equals)...]) else { throw fault("\(key) has a value that cannot be read") }
            if let array {
                let last = arrays[array]!.count - 1
                guard arrays[array]![last][key] == nil else { throw fault("\(key) is set twice") }
                arrays[array]![last][key] = value
            } else {
                guard values[key] == nil else { throw fault("\(key) is set twice") }
                values[key] = value
            }
        }
    }

    private static func value(_ source: Substring) -> Value? {
        let text = source.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("\"") { return string(text) }
        let bare = (text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .trimmingCharacters(in: .whitespaces)
        switch bare {
        case "true": return .boolean(true)
        case "false": return .boolean(false)
        default: return Int(bare).map(Value.integer)
        }
    }

    private static func string(_ text: String) -> Value? {
        var result = ""
        var escaped = false
        var rest = text.dropFirst()
        while let character = rest.popFirst() {
            if escaped {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"", "\\": result.append(character)
                default: return nil
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                let tail = rest.trimmingCharacters(in: .whitespaces)
                return tail.isEmpty || tail.hasPrefix("#") ? .string(result) : nil
            } else {
                result.append(character)
            }
        }
        return nil
    }
}
