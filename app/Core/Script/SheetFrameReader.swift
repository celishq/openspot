import Foundation

/// Splits what a script prints into frames. A line `---` ends a frame. It keeps a line that has not ended, so a chunk can
/// stop anywhere, even inside a character.
public struct SheetFrameReader: Sendable {
    public static let mark = "---"

    private var line = Data()
    private var frame = ""

    public init() {}

    /// Takes the next chunk, and returns each frame it completes.
    public mutating func read(_ data: Data) -> [String] {
        var frames: [String] = []
        for byte in data {
            guard byte == UInt8(ascii: "\n") else {
                line.append(byte)
                continue
            }
            let text = String(decoding: line, as: UTF8.self)
            line.removeAll(keepingCapacity: true)
            if text == Self.mark {
                frames.append(frame)
                frame = ""
            } else {
                frame += text + "\n"
            }
        }
        return frames
    }

    /// Returns what is left when the output ends, or nil when nothing is.
    public mutating func finish() -> String? {
        if !line.isEmpty {
            frame += String(decoding: line, as: UTF8.self)
            line.removeAll()
        }
        defer { frame = "" }
        return frame.isEmpty ? nil : frame
    }
}
