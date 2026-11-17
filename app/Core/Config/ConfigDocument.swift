import Foundation

public struct ConfigDocument: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case string(String)
        case integer(Int)
        case number(Double)
        case boolean(Bool)
        case strings([String])
        case table([String: String])

        public var number: Double? {
            switch self {
            case .integer(let number): Double(number)
            case .number(let number): number
            default: nil
            }
        }

        var text: String {
            switch self {
            case .string(let text): Self.quoted(text)
            case .integer(let number): String(number)
            case .number(let number): String(number)
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

        func text(opening: String) -> String {
            ([opening] + keys.map { "\($0) = \(values[$0]!.text)" }).joined(separator: "\n")
        }
    }

    public private(set) var head: [String] = []
    public private(set) var values: [String: Value] = [:]
    public private(set) var sections: [Table] = []
    public var tables: [Table] = []

    public init() {}

    public init(text: String) throws {
        var isInSection = false
        for (index, scalars) in text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let raw = String(scalars)
            let line = raw.trimmingCharacters(in: .whitespaces)
            let fault = { (reason: String) in SpotError.fault("line \(index + 1): \(reason)") }
            if line.hasPrefix("[[") {
                guard let end = line.range(of: "]]") else { throw fault("expected a table such as [[commands]]") }
                tables.append(Table(String(line[line.index(line.startIndex, offsetBy: 2)..<end.lowerBound])))
                isInSection = false
                continue
            }
            if line.hasPrefix("[") {
                guard let end = line.firstIndex(of: "]"), Self.isEnd(line[line.index(after: end)...].unicodeScalars) else {
                    throw fault("expected a section such as [dark]")
                }
                let name = String(line[line.index(after: line.startIndex)..<end]).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { throw fault("expected a section such as [dark]") }
                guard !sections.contains(where: { $0.name == name }) else { throw fault("[\(name)] is set twice") }
                sections.append(Table(name))
                isInSection = true
                continue
            }
            if tables.isEmpty, sections.isEmpty { head.append(raw) }
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let equals = line.unicodeScalars.firstIndex(of: "=") else { throw fault("expected a key and a value") }
            let key = String(line.unicodeScalars[..<equals]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains(" ") else { throw fault("expected a key and a value") }
            guard let value = Self.value(line.unicodeScalars[line.unicodeScalars.index(after: equals)...]) else { throw fault("\(key) has a value that cannot be read") }
            if isInSection {
                guard sections[sections.count - 1][key] == nil else { throw fault("\(key) is set twice") }
                sections[sections.count - 1][key] = value
            } else if tables.isEmpty {
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

    public static func text(_ text: String, setting key: String, in section: String, to value: Value?) -> String {
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let words = { (line: String) in line.trimmingCharacters(in: .whitespaces) }
        let name = { (line: String) in line.split(separator: "=", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } }
        let line = value.map { "\(key) = \($0.text)" }
        guard let start = lines.firstIndex(where: { words($0) == "[\(section)]" }) else {
            guard let line else { return text }
            while lines.last.map(words) == "" { lines.removeLast() }
            return (lines + (lines.isEmpty ? [] : [""]) + ["[\(section)]", line]).joined(separator: "\n") + "\n"
        }
        let end = lines[(start + 1)...].firstIndex { words($0).hasPrefix("[") } ?? lines.count
        let range = (start + 1)..<end
        let set = range.first { !words(lines[$0]).hasPrefix("#") && name(lines[$0]) == key }
        let kept = range.first { index in
            let words = words(lines[index])
            return words.hasPrefix("#") && words.contains("=") && name(String(words.drop { $0 == "#" || $0 == " " })) == key
        }
        switch (line, set, kept) {
        case (let line?, let index?, _), (let line?, nil, let index?):
            lines[index] = line
        case (let line?, nil, nil):
            let last = range.last { !words(lines[$0]).isEmpty } ?? start
            lines.insert(line, at: last + 1)
        case (nil, let index?, _):
            lines[index] = "# " + words(lines[index])
        case (nil, nil, _):
            return text
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public var text: String {
        let parts = (head.isEmpty ? [] : [head.joined(separator: "\n")]) + sections.map { $0.text(opening: "[\($0.name)]") }
            + tables.map { $0.text(opening: "[[\($0.name)]]") }
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
        default:
            if let integer = Int(bare) { return .integer(integer) }
            guard bare.contains("."), bare.allSatisfy({ "0123456789.-".contains($0) }), let number = Double(bare) else { return nil }
            return .number(number)
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
