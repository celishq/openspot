import Foundation

public struct ConfigDocument: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case string(String)
        case integer(Int)
        case boolean(Bool)
        case strings([String])
        case table([String: String])

        var text: String {
            switch self {
            case .string(let text): Self.quoted(text)
            case .integer(let number): String(number)
            case .boolean(let isOn): String(isOn)
            case .strings(let items): "[\(items.map(Self.quoted).joined(separator: ", "))]"
            case .table(let pairs): "{ \(pairs.sorted { $0.key < $1.key }.map { "\($0.key) = \(Self.quoted($0.value))" }.joined(separator: ", ")) }"
            }
        }

        private static func quoted(_ text: String) -> String {
            let escapes: [Unicode.Scalar: String] = ["\\": "\\\\", "\"": "\\\"", "\n": "\\n", "\t": "\\t"]
            return "\"\(text.unicodeScalars.map { escapes[$0] ?? String($0) }.joined())\""
        }
    }

    public struct Table: Equatable, Sendable {
        public let name: String
        public private(set) var keys: [String] = []
        private var values: [String: Value] = [:]

        public init(_ name: String, _ fields: [(String, Value?)] = []) {
            self.name = name
            for (key, value) in fields {
                if let value { self[key] = value }
            }
        }

        public subscript(key: String) -> Value? {
            get { values[key] }
            set {
                if values[key] == nil, newValue != nil { keys.append(key) }
                if newValue == nil { keys.removeAll { $0 == key } }
                values[key] = newValue
            }
        }

        var text: String {
            (["[[\(name)]]"] + keys.map { "\($0) = \(values[$0]!.text)" }).joined(separator: "\n")
        }
    }

    public private(set) var head: [String] = []
    public private(set) var values: [String: Value] = [:]
    public var tables: [Table] = []

    public init() {}

    public init(text: String) throws {
        for (index, scalars) in text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let raw = String(scalars)
            let line = raw.trimmingCharacters(in: .whitespaces)
            let fault = { (reason: String) in SpotError.fault("line \(index + 1): \(reason)") }
            if line.hasPrefix("[") {
                guard line.hasPrefix("[["), let end = line.range(of: "]]") else {
                    throw fault("only arrays of tables are allowed, as in [[commands]]")
                }
                tables.append(Table(String(line[line.index(line.startIndex, offsetBy: 2)..<end.lowerBound])))
                continue
            }
            if tables.isEmpty { head.append(raw) }
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let equals = line.unicodeScalars.firstIndex(of: "=") else { throw fault("expected a key and a value") }
            let key = String(line.unicodeScalars[..<equals]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains(" ") else { throw fault("expected a key and a value") }
            guard let value = Self.value(line.unicodeScalars[line.unicodeScalars.index(after: equals)...]) else { throw fault("\(key) has a value that cannot be read") }
            if tables.isEmpty {
                guard values[key] == nil else { throw fault("\(key) is set twice") }
                values[key] = value
            } else {
                guard tables[tables.count - 1][key] == nil else { throw fault("\(key) is set twice") }
                tables[tables.count - 1][key] = value
            }
        }
        while head.last?.trimmingCharacters(in: .whitespaces) == "" { head.removeLast() }
    }

    public func tables(named name: String) -> [Table] {
        tables.filter { $0.name == name }
    }

    public mutating func set(_ key: String, to value: Value) {
        let line = "\(key) = \(value.text)"
        if let index = head.firstIndex(where: { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == key }) {
            head[index] = line
        } else {
            head.append(line)
        }
        values[key] = value
    }

    public var text: String {
        let parts = (head.isEmpty ? [] : [head.joined(separator: "\n")]) + tables.map(\.text)
        return parts.isEmpty ? "" : parts.joined(separator: "\n\n") + "\n"
    }

    private static func value(_ source: Substring.UnicodeScalarView) -> Value? {
        let text = String(source).trimmingCharacters(in: .whitespaces)
        var rest = text.unicodeScalars[...]
        switch rest.first {
        case "\"":
            rest.removeFirst()
            guard let result = quoted(&rest) else { return nil }
            return isEnd(rest) ? .string(result) : nil
        case "[":
            rest.removeFirst()
            return strings(rest)
        case "{":
            rest.removeFirst()
            return table(rest)
        default:
            break
        }
        let bare = String(rest.prefix { $0 != "#" }).trimmingCharacters(in: .whitespaces)
        switch bare {
        case "true": return .boolean(true)
        case "false": return .boolean(false)
        default: return Int(bare).map(Value.integer)
        }
    }

    private static func isEnd(_ rest: Substring.UnicodeScalarView) -> Bool {
        let tail = String(rest).trimmingCharacters(in: .whitespaces)
        return tail.isEmpty || tail.unicodeScalars.first == "#"
    }

    private static func strings(_ text: Substring.UnicodeScalarView) -> Value? {
        var result: [String] = []
        var rest = text
        while let scalar = rest.popFirst() {
            switch scalar {
            case " ", "\t", ",":
                continue
            case "\"":
                guard let item = quoted(&rest) else { return nil }
                result.append(item)
            case "]":
                return isEnd(rest) ? .strings(result) : nil
            default:
                return nil
            }
        }
        return nil
    }

    private static func table(_ text: Substring.UnicodeScalarView) -> Value? {
        var result: [String: String] = [:]
        var rest = text
        var key = ""
        while let scalar = rest.popFirst() {
            switch scalar {
            case " ", "\t", ",":
                continue
            case "=":
                rest = rest.drop { $0 == " " }
                guard rest.popFirst() == "\"", !key.isEmpty, let item = quoted(&rest), result[key] == nil else { return nil }
                result[key] = item
                key = ""
            case "}":
                return key.isEmpty && isEnd(rest) ? .table(result) : nil
            default:
                key.unicodeScalars.append(scalar)
            }
        }
        return nil
    }

    private static func quoted(_ rest: inout Substring.UnicodeScalarView) -> String? {
        var result = String.UnicodeScalarView()
        var escaped = false
        while let scalar = rest.popFirst() {
            if escaped {
                switch scalar {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"", "\\": result.append(scalar)
                default: return nil
                }
                escaped = false
            } else if scalar == "\\" {
                escaped = true
            } else if scalar == "\"" {
                return String(result)
            } else {
                result.append(scalar)
            }
        }
        return nil
    }
}
