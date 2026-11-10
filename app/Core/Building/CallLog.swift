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
            let parts = [("stdin", input ?? ""), ("stdout", frames.joined(separator: "---\n")), ("stderr", errors)]
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

    /// The records of one spot, the oldest first, after each write that came before.
    public func text(of id: String) -> String {
        queue.sync { (try? String(contentsOf: file(of: id), encoding: .utf8)) ?? "" }
    }

    /// Takes away the records of one spot.
    public func remove(_ id: String) {
        queue.async { try? FileManager.default.removeItem(at: self.file(of: id)) }
    }

    private func file(of id: String) -> URL {
        folder.appendingPathComponent("\(id).log")
    }

    private func append(_ record: Record) {
        let file = file(of: record.spot)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var text = ((try? String(contentsOf: file, encoding: .utf8)) ?? "") + record.text(within: limit)
        while text.utf8.count > limit, let next = text.dropFirst().range(of: "\n\(Self.mark)") {
            text = String(text[text.index(after: next.lowerBound)...])
        }
        try? text.write(to: file, atomically: true, encoding: .utf8)
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
