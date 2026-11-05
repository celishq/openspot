import Foundation

/// The part of TOML a widget file uses: top-level pairs and arrays of tables, with strings, integers, booleans and one-line lists of strings.
public struct TomlDocument: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case string(String)
        case integer(Int)
        case boolean(Bool)
        case strings([String])
    }

    public private(set) var values: [String: Value] = [:]
    public private(set) var arrays: [String: [[String: Value]]] = [:]

    public init(text: String) throws {
        var array: String?
        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let fault = { (reason: String) in PluginError.fault("line \(index + 1): \(reason)") }
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
        if text.hasPrefix("[") { return strings(text) }
        let bare = (text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .trimmingCharacters(in: .whitespaces)
        switch bare {
        case "true": return .boolean(true)
        case "false": return .boolean(false)
        default: return Int(bare).map(Value.integer)
        }
    }

    private static func string(_ text: String) -> Value? {
        var rest = text.dropFirst()
        guard let result = quoted(&rest) else { return nil }
        let tail = rest.trimmingCharacters(in: .whitespaces)
        return tail.isEmpty || tail.hasPrefix("#") ? .string(result) : nil
    }

    private static func strings(_ text: String) -> Value? {
        var result: [String] = []
        var rest = text.dropFirst()
        while let character = rest.popFirst() {
            switch character {
            case " ", "\t", ",":
                continue
            case "\"":
                guard let item = quoted(&rest) else { return nil }
                result.append(item)
            case "]":
                let tail = rest.trimmingCharacters(in: .whitespaces)
                return tail.isEmpty || tail.hasPrefix("#") ? .strings(result) : nil
            default:
                return nil
            }
        }
        return nil
    }

    /// Reads up to the closing quote, and leaves what follows it.
    private static func quoted(_ rest: inout Substring) -> String? {
        var result = ""
        var escaped = false
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
                return result
            } else {
                result.append(character)
            }
        }
        return nil
    }
}
