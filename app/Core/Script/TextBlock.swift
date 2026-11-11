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

    private static let newLine = UInt8(ascii: "\n")
    private static let carriageReturn = UInt8(ascii: "\r")
    private static let equalsSign = UInt8(ascii: "=")
    private static let backslash = UInt8(ascii: "\\")
    private static let letterN = UInt8(ascii: "n")

    public let fields: [Field]
    /// The first line as a script printed it, which names a block that cannot be read.
    public let firstLine: String
    /// The blocks that belong to this one, such as the options after a choice.
    public let children: [TextBlock]

    public init(fields: [Field], firstLine: String = "", children: [TextBlock] = []) {
        self.fields = fields
        self.firstLine = firstLine
        self.children = children
    }

    /// This block with one more block that belongs to it.
    func adding(child: TextBlock) -> TextBlock {
        TextBlock(fields: fields, firstLine: firstLine, children: children + [child])
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
        var text = output
        text.withUTF8 { bytes in
            var start = 0
            while start <= bytes.count {
                let end = next(newLine, in: bytes, from: start, to: bytes.count)
                let stop = end > start && bytes[end - 1] == carriageReturn ? end - 1 : end
                let equals = next(equalsSign, in: bytes, from: start, to: stop)
                if equals == stop, string(bytes, start, stop).allSatisfy(\.isWhitespace) {
                    close()
                } else {
                    if firstLine == nil { firstLine = string(bytes, start, stop) }
                    if equals != stop, equals != start {
                        fields.append(Field(key: string(bytes, start, equals), value: unescaped(bytes, equals + 1, stop)))
                    }
                }
                start = end + 1
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
        var value = value
        return value.withUTF8 { bytes in
            String(unsafeUninitializedCapacity: bytes.count * 2) { out in
                var read = 0
                var written = 0
                var slash = next(backslash, in: bytes, from: 0, to: bytes.count)
                var line = next(newLine, in: bytes, from: 0, to: bytes.count)
                while read < bytes.count {
                    let mark = min(slash, line)
                    written += copy(bytes, read, mark, to: out, at: written)
                    guard mark < bytes.count else { break }
                    out[written] = backslash
                    out[written + 1] = mark == slash ? backslash : letterN
                    written += 2
                    read = mark + 1
                    if mark == slash {
                        slash = next(backslash, in: bytes, from: read, to: bytes.count)
                    } else {
                        line = next(newLine, in: bytes, from: read, to: bytes.count)
                    }
                }
                return written
            }
        }
    }

    private static func unescaped(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> String {
        String(unsafeUninitializedCapacity: end - start) { out in
            var read = start
            var written = 0
            while read < end {
                let slash = next(backslash, in: bytes, from: read, to: end)
                written += copy(bytes, read, slash, to: out, at: written)
                guard slash < end else { break }
                read = slash + 1
                if read < end, bytes[read] == letterN || bytes[read] == backslash {
                    out[written] = bytes[read] == letterN ? newLine : backslash
                    read += 1
                } else {
                    out[written] = backslash
                }
                written += 1
            }
            return written
        }
    }

    private static func string(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int) -> String {
        String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self)
    }

    /// Where this byte next lies in the range, or the end of the range.
    private static func next(_ byte: UInt8, in bytes: UnsafeBufferPointer<UInt8>, from start: Int, to end: Int) -> Int {
        guard start < end, let base = bytes.baseAddress, let found = memchr(base + start, Int32(byte), end - start) else { return end }
        return UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) - base
    }

    /// Copies the range, and returns how many bytes it copied.
    private static func copy(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ end: Int, to out: UnsafeMutableBufferPointer<UInt8>, at offset: Int) -> Int {
        guard start < end, let source = bytes.baseAddress, let target = out.baseAddress else { return 0 }
        memcpy(target + offset, source + start, end - start)
        return end - start
    }
}
