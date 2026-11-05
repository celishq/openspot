import Foundation

/// A group of `key=value` lines, the form of all that a script prints and reads. A blank line ends a block.
/// In a value, `\n` stands for a new line and `\\` for a backslash. An empty value counts as no value.
public struct TextBlock: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let key: String
        public let value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public let fields: [Field]
    /// The first line as a script printed it, which names a block that cannot be read.
    public let firstLine: String

    public init(fields: [Field], firstLine: String = "") {
        self.fields = fields
        self.firstLine = firstLine
    }

    /// The blocks in what a script prints. A line with no key is skipped.
    public static func blocks(in output: String) -> [TextBlock] {
        var blocks: [TextBlock] = []
        var fields: [Field] = []
        var firstLine: String?
        func close() {
            if let line = firstLine { blocks.append(TextBlock(fields: fields, firstLine: line)) }
            fields = []
            firstLine = nil
        }
        for scalars in output.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(String.UnicodeScalarView(scalars.last == "\r" ? scalars.dropLast() : scalars))
            if line.allSatisfy(\.isWhitespace) {
                close()
                continue
            }
            if firstLine == nil { firstLine = line }
            if let equals = line.firstIndex(of: "="), equals != line.startIndex {
                fields.append(Field(key: String(line[..<equals]), value: unescaped(line[line.index(after: equals)...])))
            }
        }
        close()
        return blocks
    }

    /// The lines of this block, for a script to read.
    public var text: String {
        fields.map { "\($0.key)=\(Self.escaped($0.value))\n" }.joined()
    }

    public func value(_ key: String) -> String? {
        fields.first { $0.key == key && !$0.value.isEmpty }?.value
    }

    public func values(_ key: String) -> [String] {
        fields.filter { $0.key == key && !$0.value.isEmpty }.map(\.value)
    }

    public func number(_ key: String) -> Double? {
        value(key).flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil }
    }

    public func flag(_ key: String) -> Bool? {
        value(key).flatMap(Bool.init)
    }

    private static func escaped(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": scalars.append(contentsOf: "\\\\".unicodeScalars)
            case "\n": scalars.append(contentsOf: "\\n".unicodeScalars)
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static func unescaped(_ value: Substring) -> String {
        var scalars = String.UnicodeScalarView()
        var rest = value.unicodeScalars[...]
        while let scalar = rest.popFirst() {
            guard scalar == "\\", let next = rest.first, next == "n" || next == "\\" else {
                scalars.append(scalar)
                continue
            }
            rest.removeFirst()
            scalars.append(next == "n" ? "\n" : "\\")
        }
        return String(scalars)
    }
}
