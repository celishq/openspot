import Foundation

/// The record of the calls of each spot: one text file for each spot in a folder, which keeps the newest calls within a
/// limit. A person or an agent reads it to see what a call got and gave. It writes on a queue of its own.
public final class CallLog: Sendable {
    /// How a call ended.
    public enum End: Equatable, Sendable {
        case exited(Int32)
        case stopped
        case failed(String)
    }

    /// One call: what it got, what it printed and how it ended.
    public struct Record: Sendable {
        public let spot: String
        public let arguments: [String]
        public let input: String?
        public let frames: [String]
        public let errors: String
        public let end: End
        public let started: Date
        public let seconds: Double

        public init(spot: String, arguments: [String], input: String?, frames: [String], errors: String, end: End, started: Date, seconds: Double) {
            self.spot = spot
            self.arguments = arguments
            self.input = input
            self.frames = frames
            self.errors = errors
            self.end = end
            self.started = started
            self.seconds = seconds
        }

        /// The record as text, with each part cut to a share of the limit of its file.
        func text(within limit: Int) -> String {
            let ending = switch end {
            case .exited(let code): "exit \(code)"
            case .stopped: frames.isEmpty ? "stopped" : "stopped after its answer"
            case .failed(let reason): reason
            }
            let head = "\(CallLog.mark)\(started.formatted(.iso8601)) · \(arguments.joined(separator: " ")) · \(ending) · \(String(format: "%.2f", seconds)) s\n"
            let share = limit / 4
            let printed = frames[CallLog.firstShown(of: frames, within: share)...].joined(separator: CallLog.frameSeparator)
            let parts = [("stdin", input ?? ""), ("stdout", printed), ("stderr", errors)]
                .filter { !$0.1.isEmpty }
                .map { "\($0.0):\n\(Self.tail(of: $0.1, within: share))" }
            return head + parts.map { $0.hasSuffix("\n") ? $0 : $0 + "\n" }.joined() + "\n"
        }

        private static func tail(of text: String, within limit: Int) -> String {
            guard text.utf8.count > limit else { return text }
            return "…" + String(decoding: text.utf8.suffix(limit), as: UTF8.self)
        }
    }

    /// The start of each record in a file.
    public static let mark = "== "
    private static let frameSeparator = "---\n"

    public let folder: URL
    private let limit: Int
    private let queue = DispatchQueue(label: "openspot.call-log")

    public init(folder: URL, limit: Int = 64_000) {
        self.folder = folder
        self.limit = limit
    }

    /// Adds a record to the file of its spot, after the records that came before it.
    public func write(_ record: Record) {
        queue.async { self.append(record) }
    }

    /// The records of one spot within the limit, the oldest first, after each write that came before.
    public func text(of id: String) -> String {
        queue.sync { (try? Data(contentsOf: file(of: id))).map { String(decoding: Self.newest($0, within: limit), as: UTF8.self) } ?? "" }
    }

    /// Adds a frame that a call printed, and drops each older frame that the record of the call would not show.
    public func add(_ frame: String, to frames: inout [String]) {
        frames.append(frame)
        let first = Self.firstShown(of: frames, within: limit / 4)
        if first > 0 { frames.removeFirst(first) }
    }

    /// The index of the first frame that the end of the printed text shows, when it shows this many bytes.
    private static func firstShown(of frames: [String], within share: Int) -> Int {
        var first = frames.count
        var bytes = 0
        while first > 0, bytes <= share + frameSeparator.utf8.count {
            first -= 1
            bytes += frames[first].utf8.count + frameSeparator.utf8.count
        }
        return first
    }

    /// The newest whole records of a log that fit in the limit, or the last record alone when it does not fit.
    private static func newest(_ log: Data, within limit: Int) -> Data {
        guard log.count > limit else { return log }
        let start = Data("\n\(mark)".utf8)
        let earliest = log.startIndex + log.count - limit - 1
        guard let cut = log.range(of: start, in: earliest..<log.endIndex) ?? log.range(of: start, options: .backwards) else { return log }
        return log[(cut.lowerBound + 1)...]
    }

    /// Takes away the records of one spot.
    public func remove(_ id: String) {
        queue.async { try? FileManager.default.removeItem(at: self.file(of: id)) }
    }

    private func file(of id: String) -> URL {
        folder.appendingPathComponent("\(id).log")
    }

    /// Adds a record at the end of the file. A file that passes twice the limit keeps only its newest records within it.
    private func append(_ record: Record) {
        let file = file(of: record.spot)
        let text = Data(record.text(within: limit).utf8)
        guard let handle = try? FileHandle(forWritingTo: file) else {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: file)
            return
        }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), Int(size) + text.count > 2 * limit, let old = try? Data(contentsOf: file) else {
            try? handle.write(contentsOf: text)
            return
        }
        try? Self.newest(old + text, within: limit).write(to: file, options: .atomic)
    }
}

extension CallLog.End {
    /// How a call of a run ended, in the words of the log.
    init(_ end: ScriptCall.End) {
        switch end {
        case .ended: self = .exited(0)
        case .stopped: self = .stopped
        case .failed(let error):
            switch error as? PluginError {
            case .failed(let code, _)?, .failedWithFix(let code, _, _)?: self = .exited(code)
            case let error?: self = .failed(error.reason)
            case nil: self = .failed(error.localizedDescription)
            }
        }
    }
}
