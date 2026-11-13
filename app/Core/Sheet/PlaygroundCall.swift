import Foundation

/// One call as the playground shows it: a line of its arguments and reason, then its stdin, its frames and its stderr, each
/// line marked by where it went, then how it ended.
public struct PlaygroundCall: Equatable, Sendable {
    public let lines: [String]

    public init(record: CallLog.Record, reason: ReadReason?) {
        let words = record.arguments.map { $0.contains(where: \.isWhitespace) || $0.isEmpty ? "'\($0)'" : $0 }.joined(separator: " ")
        let why = reason.map { [" · OPENSPOT_REASON=\($0.rawValue)"] + ($0.value.map { [" OPENSPOT_VALUE=\($0)"] } ?? []) }?.joined() ?? ""
        let ending = switch record.end {
        case .exited(let code): "exit \(code)"
        case .stopped: "stopped"
        case .failed(let reason): reason
        }
        lines = ["$ \(words)\(why)"]
            + Self.lines(of: record.input ?? "", mark: "<")
            + record.frames.map { Self.lines(of: $0, mark: ">") }.joined(separator: ["> ---"])
            + Self.lines(of: record.errors, mark: "!")
            + ["= \(ending)"]
    }

    private static func lines(of text: String, mark: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map { "\(mark) \($0)" }
    }
}
