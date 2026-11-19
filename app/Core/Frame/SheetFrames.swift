import Foundation

public struct SheetFrames: Sendable {
    public static let mark = "---"

    private enum Escape: Sendable {
        case none
        case start
        case control
        case command
        case commandEnd
    }

    public static let limit = 32 << 20

    private let limit: Int
    private var line = Data()
    private var frame = ""
    private var escape = Escape.none
    public private(set) var isOverLimit = false

    public init(limit: Int = Self.limit) {
        self.limit = limit
    }

    public mutating func read(_ data: Data) -> [String] {
        guard escape == .none else { return readEscaped(data) }
        return data.withUnsafeBytes { raw -> [String]? in
            guard let base = raw.baseAddress else { return [] }
            guard memchr(base, 0x1B, raw.count) == nil else { return nil }
            var frames: [String] = []
            var start = 0
            while start < raw.count, let found = memchr(base + start, 0x0A, raw.count - start) {
                let end = base.distance(to: UnsafeRawPointer(found))
                line.append(contentsOf: UnsafeRawBufferPointer(rebasing: raw[start..<end]))
                endLine(into: &frames)
                start = end + 1
            }
            line.append(contentsOf: UnsafeRawBufferPointer(rebasing: raw[start...]))
            checkLine()
            return frames
        } ?? readEscaped(data)
    }

    private mutating func endLine(into frames: inout [String]) {
        let text = String(decoding: line, as: UTF8.self)
        line.removeAll(keepingCapacity: true)
        if isOverLimit { return }
        if text == Self.mark {
            frames.append(frame)
            frame = ""
        } else if frame.utf8.count + text.utf8.count >= limit {
            drop()
        } else {
            frame += text + "\n"
        }
    }

    private mutating func checkLine() {
        if line.count + frame.utf8.count >= limit { drop() }
    }

    private mutating func drop() {
        isOverLimit = true
        frame = ""
        line = Data()
    }

    private mutating func readEscaped(_ data: Data) -> [String] {
        var frames: [String] = []
        for byte in data {
            switch escape {
            case .start:
                escape = byte == UInt8(ascii: "[") ? .control : byte == UInt8(ascii: "]") ? .command : .none
            case .control:
                if (0x40...0x7E).contains(byte) { escape = .none }
            case .command:
                if byte == 0x07 {
                    escape = .none
                } else if byte == 0x1B {
                    escape = .commandEnd
                }
            case .commandEnd:
                escape = .none
            case .none:
                if byte == 0x1B {
                    escape = .start
                } else if byte == UInt8(ascii: "\n") {
                    endLine(into: &frames)
                } else {
                    line.append(byte)
                }
            }
        }
        checkLine()
        return frames
    }

    public mutating func finish() -> String? {
        guard !isOverLimit else { return nil }
        if !line.isEmpty {
            frame += String(decoding: line, as: UTF8.self)
            line.removeAll()
        }
        defer { frame = "" }
        return frame.isEmpty ? nil : frame
    }
}
