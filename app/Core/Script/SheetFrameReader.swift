import Foundation

/// Splits what a script prints into frames. A line `---` ends a frame. It keeps a line that has not ended, so a chunk can
/// stop anywhere, even inside a character. A terminal's progress code (OSC 9;4) and notification code (OSC 9) each give a
/// frame of their own, and each other escape code leaves the text (protocol: Frames).
public struct SheetFrameReader: Sendable {
    public static let mark = "---"

    private enum Escape: Sendable {
        case none
        case start
        case control
        case command
        case commandEnd
    }

    private var line = Data()
    private var frame = ""
    private var escape = Escape.none
    private var command = Data()

    public init() {}

    /// Takes the next chunk, and returns each frame it completes.
    public mutating func read(_ data: Data) -> [String] {
        var frames: [String] = []
        for byte in data {
            switch escape {
            case .start:
                escape = byte == UInt8(ascii: "[") ? .control : byte == UInt8(ascii: "]") ? .command : .none
                command.removeAll(keepingCapacity: true)
            case .control:
                if (0x40...0x7E).contains(byte) { escape = .none }
            case .command:
                if byte == 0x07 {
                    escape = .none
                    frames += Self.frame(of: command)
                } else if byte == 0x1B {
                    escape = .commandEnd
                } else {
                    command.append(byte)
                }
            case .commandEnd:
                escape = .none
                frames += Self.frame(of: command)
            case .none:
                if byte == 0x1B {
                    escape = .start
                } else if byte == UInt8(ascii: "\n") {
                    let text = String(decoding: line, as: UTF8.self)
                    line.removeAll(keepingCapacity: true)
                    if text == Self.mark {
                        frames.append(frame)
                        frame = ""
                    } else {
                        frame += text + "\n"
                    }
                } else {
                    line.append(byte)
                }
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

    /// The frame of one operating system command: `progress` from a progress code that sets a percent, `toast` from a
    /// notification, and none from any other.
    private static func frame(of command: Data) -> [String] {
        let text = String(decoding: command, as: UTF8.self)
        if text.hasPrefix("9;4;") {
            let parts = text.split(separator: ";", omittingEmptySubsequences: false)
            guard parts.count >= 4, ["1", "2", "4"].contains(parts[2]), let percent = Double(parts[3]) else { return [] }
            return [TextBlock(fields: [.init(key: "progress", value: "\(min(max(percent, 0), 100) / 100)")]).text]
        }
        guard text.hasPrefix("9;"), text.count > 2 else { return [] }
        return [TextBlock(fields: [.init(key: "toast", value: String(text.dropFirst(2)))]).text]
    }
}
