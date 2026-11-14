import Foundation

public final class CallLog: Sendable {
    public enum End: Equatable, Sendable {
        case exited(Int32)
        case stopped
        case failed(String)
    }

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

        func text(within limit: Int) -> String {
            let ending = switch end {
            case .exited(let code): "exit \(code)"
            case .stopped: frames.isEmpty ? "stopped" : "stopped after its answer"
            case .failed(let reason): reason
            }
            let head = "\(CallLog.recordMark)\(started.formatted(.iso8601)) · \(arguments.joined(separator: " ")) · \(ending) · \(String(format: "%.2f", seconds)) s\n"
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

    public static let recordMark = "== "
    private static let frameSeparator = "---\n"

    public let folder: URL
    private let limit: Int
    private let queue = DispatchQueue(label: "openspot.call-log")

    public init(folder: URL, limit: Int = 64_000) {
        self.folder = folder
        self.limit = limit
    }

    public func write(_ record: Record) {
        queue.async { self.append(record) }
    }

    public func text(of id: String) -> String {
        queue.sync { (try? Data(contentsOf: file(of: id))).map { String(decoding: Self.newest($0, within: limit), as: UTF8.self) } ?? "" }
    }

    public func add(_ frame: String, to frames: inout [String]) {
        frames.append(frame)
        let first = Self.firstShown(of: frames, within: limit / 4)
        if first > 0 { frames.removeFirst(first) }
    }

    private static func firstShown(of frames: [String], within share: Int) -> Int {
        var first = frames.count
        var bytes = 0
        while first > 0, bytes <= share + frameSeparator.utf8.count {
            first -= 1
            bytes += frames[first].utf8.count + frameSeparator.utf8.count
        }
        return first
    }

    private static func newest(_ log: Data, within limit: Int) -> Data {
        guard log.count > limit else { return log }
        let start = Data("\n\(recordMark)".utf8)
        let earliest = log.startIndex + log.count - limit - 1
        guard let cut = log.range(of: start, in: earliest..<log.endIndex) ?? log.range(of: start, options: .backwards) else { return log }
        return log[(cut.lowerBound + 1)...]
    }

    public func remove(_ id: String) {
        queue.async { try? FileManager.default.removeItem(at: self.file(of: id)) }
    }

    private func file(of id: String) -> URL {
        folder.appendingPathComponent("\(id).log")
    }

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
    init(_ end: ScriptCall.End) {
        switch end {
        case .ended: self = .exited(0)
        case .stopped: self = .stopped
        case .failed(let error):
            switch error as? SpotError {
            case .failed(let code, _)?, .failedWithFix(let code, _, _)?: self = .exited(code)
            case let error?: self = .failed(error.reason)
            case nil: self = .failed(error.localizedDescription)
            }
        }
    }
}
