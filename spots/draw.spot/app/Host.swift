import Foundation

/// Openspot at the other end of stdin and stdout. It writes each call as a block of lines and a blank line, and takes
/// each frame that Draw prints.
final class Host: @unchecked Sendable {
    private let lock = NSLock()
    private let output: FileHandle

    /// The host that reads what Draw prints from `output`.
    init(output: FileHandle = .standardOutput) {
        self.output = output
    }

    /// Reads the blocks of stdin on a thread of its own and hands each call to `take` on the main thread. It hands nil
    /// when stdin closes, which is how Openspot says that it no longer wants Draw.
    func listen(_ take: @escaping @MainActor @Sendable (Call?) -> Void) {
        let reading = Thread {
            var lines: [String] = []
            while let line = readLine(strippingNewline: true) {
                if !line.isEmpty {
                    lines.append(line)
                    continue
                }
                let call = Call(lines: lines)
                lines = []
                if let call { DispatchQueue.main.async { take(call) } }
            }
            DispatchQueue.main.async { take(nil) }
        }
        reading.name = "draw.host"
        reading.start()
    }

    /// Prints one frame.
    func send(_ frame: String) {
        lock.withLock {
            output.write(Data((frame + (frame.hasSuffix("\n") ? "" : "\n") + "---\n").utf8))
        }
    }
}
